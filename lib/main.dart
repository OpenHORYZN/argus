import 'dart:async';
import 'dart:collection';

import 'package:argus/fab.dart';
import 'package:argus/map.dart';
import 'package:argus/plot.dart';
import 'package:argus/title_bar/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:argus/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

const machine = "sim";

Future<void> main() async {
  await RustLib.init();
  runApp(const Argus());
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setAsFrameless();
  });
}

class Argus extends StatelessWidget {
  const Argus({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MissionPlannerPage(),
      darkTheme: ThemeData.localize(ThemeData.dark(useMaterial3: true),
          Theme.of(context).textTheme.apply(fontSizeFactor: 0.8)),
      themeMode: ThemeMode.dark,
    );
  }
}

class MissionPlannerPage extends StatefulWidget {
  const MissionPlannerPage({super.key});

  @override
  State<MissionPlannerPage> createState() => _MissionPlannerPageState();
}

class _MissionPlannerPageState extends State<MissionPlannerPage> {
  final uuid = const Uuid();
  final logger = Logger(printer: SimplePrinter());

  CoreConnection? _connection;
  Stream<PositionTriple>? _posStream;
  Stream<double>? _yawStream;
  Stream<int>? _stepStream;
  Stream<bool>? _onlineStream;
  Stream<FlutterControlResponse>? _controlStream;
  bool _online = false;
  bool _paused = false;
  final _mapController = MapController();
  final _plotController = PlotController();

  void _connect(MissionPlanList missionNodes) {
    if (_connection == null) {
      CoreConnection.init(machine: machine).then((conn) async {
        _connection = conn;
        _posStream = (await conn.getPos()).asBroadcastStream();
        _onlineStream = (await conn.getOnline()).asBroadcastStream();
        _stepStream = (await conn.getStep()).asBroadcastStream();
        _controlStream = (await conn.getControl()).asBroadcastStream();
        _yawStream = (await conn.getYaw()).asBroadcastStream();
        setState(() {});

        _posStream!.first.then((p) {
          logger.i("Re-Centering Map");
          _mapController.move(LatLng(p.x, p.y), _mapController.camera.zoom);
        }, onError: (_) => ());

        _posStream!.forEach((p) {
          _plotController.push(AltPoint(DateTime.now(), p.z));
        });

        _onlineStream!.forEach((o) async {
          if (o && !_online) {
            logger.i("Fetching Mission Plan");
            conn.sendControl(
                req: const FlutterControlRequest.fetchMissionPlan());
          }

          _online = o;
        });

        _controlStream!.forEach((p) {
          p.map(sendMissionPlan: (smp) {
            logger.i("Mission Plan Received");
            missionNodes.setList(smp.field0.nodes.toList());
          }, pauseResume: (pause) {
            setState(() {
              _paused = pause.field0;
            });
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (context) => MissionPlanList.withConnect(_connect)),
        ChangeNotifierProvider(create: (context) => MapMeta())
      ],
      child: Scaffold(
          appBar: TitleBar(
            onlineStream: _onlineStream,
            stepStream: _stepStream,
            machine: machine,
          ),
          body: Column(
            children: [
              Expanded(
                flex: 3,
                child: MainMapWidget(
                  controller: _mapController,
                  posStream: _posStream,
                  yawStream: _yawStream,
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: AltitudePlot(
                        controller: _plotController,
                      ),
                    ),
                    Expanded(
                      child: Consumer<MissionPlanList>(
                        builder: (context, missionNodes, child) =>
                            StreamBuilder<int>(
                                stream: _stepStream,
                                builder: (context, snapshot) {
                                  bool isMe(AsyncSnapshot<int> snap, index) {
                                    return (snap.data?.toInt() == index);
                                  }

                                  return ReorderableListView.builder(
                                    itemCount: missionNodes.length,
                                    buildDefaultDragHandles: false,
                                    onReorder: missionNodes.reorder,
                                    itemBuilder: (context, index) {
                                      final node =
                                          missionNodes.missionNodes[index];

                                      return ReorderableDragStartListener(
                                          index: index,
                                          key: ValueKey(node.id),
                                          enabled: !missionNodes
                                                  .isBedrock(index) &&
                                              missionNodes.isUnlocked(snapshot),
                                          child: ListTile(
                                            leading: _getIconForNode(node),
                                            title: Text(_getTextForNode(node)),
                                            textColor: isMe(snapshot, index)
                                                ? Colors.orange
                                                : null,
                                            titleTextStyle: isMe(
                                                    snapshot, index)
                                                ? const TextStyle(
                                                    fontWeight: FontWeight.bold)
                                                : const TextStyle(),
                                            trailing: !missionNodes
                                                        .isBedrock(index) &&
                                                    missionNodes
                                                        .isUnlocked(snapshot)
                                                ? IconButton(
                                                    icon: const Icon(
                                                        Icons.delete),
                                                    onPressed: () =>
                                                        missionNodes
                                                            .removeNode(index),
                                                  )
                                                : null,
                                          ));
                                    },
                                  );
                                }),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<MissionPlanList>(
                  builder: (context, missionNodes, child) =>
                      StreamBuilder<bool>(
                          stream: _onlineStream,
                          builder: (context, onlineSnapshot) {
                            return StreamBuilder<int>(
                                stream: _stepStream,
                                builder: (context, stepSnapshot) {
                                  return ElevatedButton.icon(
                                    label: const Text('Send Mission'),
                                    icon: const Icon(Icons.check),
                                    onPressed:
                                        (onlineSnapshot.hasData &&
                                                onlineSnapshot.data! &&
                                                missionNodes
                                                    .isUnlocked(stepSnapshot))
                                            ? () async {
                                                if (_connection != null) {
                                                  _connection!.sendControl(
                                                      req: const FlutterControlRequest
                                                          .fetchMissionPlan());
                                                  await _connection!.sendMissionPlan(
                                                      plan: FlutterMissionPlan(
                                                          id: uuid.v4obj(),
                                                          nodes: missionNodes
                                                              .missionNodes));
                                                }
                                              }
                                            : null,
                                  );
                                });
                          }),
                ),
              ),
            ],
          ),
          floatingActionButton: MainFAB(
            paused: _paused,
            stepStream: _stepStream,
            connection: _connection,
          )),
    );
  }

  Icon _getIconForNode(FlutterMissionNode node) {
    return node.item.map(
        init: (_) => const Icon(Icons.flag),
        takeoff: (_) => const Icon(Icons.flight_takeoff),
        waypoint: (_) => const Icon(Icons.place),
        delay: (_) => const Icon(Icons.timer),
        land: (_) => const Icon(Icons.flight_land),
        end: (_) => const Icon(Icons.stop),
        findSafeSpot: (_) => const Icon(Icons.safety_check),
        transition: (_) => const Icon(Icons.change_history),
        precLand: (_) => const Icon(Icons.location_history));
  }

  String _getTextForNode(FlutterMissionNode node) {
    return node.item.map(
        init: (_) => 'Init',
        takeoff: (t) => 'Takeoff at ${t.altitude}m',
        waypoint: (n) => n.field0.map(
            localOffset: (l) =>
                'Relative Offset [${l.field0}, ${l.field1}, ${l.field2}]',
            globalFixedHeight: (g) =>
                'GPS Waypoint ${g.lat.toStringAsFixed(5)} lat, ${g.lon.toStringAsFixed(5)} lon, ${g.alt}m AMSL',
            globalRelativeHeight: (g) {
              final general =
                  'GPS Waypoint ${g.lat.toStringAsFixed(5)} | ${g.lon.toStringAsFixed(5)}';
              if (g.heightDiff > 0) {
                return '$general| ↑ ${g.heightDiff}m';
              } else if (g.heightDiff < 0) {
                return '$general| ↓ ${g.heightDiff}m';
              } else {
                return general;
              }
            }),
        delay: (n) => 'Delay (${n.field0} seconds)',
        land: (_) => 'Land',
        end: (_) => 'End',
        findSafeSpot: (_) => 'Find Safe Spot',
        transition: (_) => 'Transition',
        precLand: (_) => 'Precision Land');
  }
}

class MapMeta extends ChangeNotifier {
  Function(LatLng)? _gpsResult;

  Function(LatLng)? get gpsResult => _gpsResult;

  void setGPSResult(Function(LatLng)? callback) {
    _gpsResult = callback;
    notifyListeners();
  }
}

class MissionPlanList extends ChangeNotifier {
  MissionPlanList();

  factory MissionPlanList.withConnect(Function(MissionPlanList) connector) {
    var self = MissionPlanList();
    connector(self);
    return self;
  }

  final List<FlutterMissionNode> _missionNodes = [
    FlutterMissionNode.random(item: const FlutterMissionItem.init()),
    FlutterMissionNode.random(
        item: const FlutterMissionItem.takeoff(altitude: 10.0)),
    FlutterMissionNode.random(item: const FlutterMissionItem.land()),
    FlutterMissionNode.random(item: const FlutterMissionItem.end()),
  ];

  UnmodifiableListView<FlutterMissionNode> get missionNodes =>
      UnmodifiableListView(_missionNodes);

  int get length => _missionNodes.length;

  void setList(List<FlutterMissionNode> newList) {
    _missionNodes.clear();
    _missionNodes.addAll(newList);
    notifyListeners();
  }

  void addNode(FlutterMissionNode node) {
    if (_missionNodes.length > 2 &&
        _missionNodes[_missionNodes.length - 2].item
            is FlutterMissionItem_Land) {
      _missionNodes.insert(_missionNodes.length - 2, node);
    } else {
      _missionNodes.insert(_missionNodes.length - 1, node);
    }
    notifyListeners();
  }

  void removeNode(int index) {
    _missionNodes.removeAt(index);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (isBedrock(oldIndex)) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    if (isBedrock(newIndex)) {
      return;
    }

    final it = _missionNodes.removeAt(oldIndex);
    _missionNodes.insert(newIndex, it);
    notifyListeners();
  }

  bool isBedrock(int index) {
    return _missionNodes[index].item is FlutterMissionItem_Init ||
        _missionNodes[index].item is FlutterMissionItem_End;
  }

  bool isUnlocked(AsyncSnapshot<int> snap) {
    return snap.data == null || snap.data! == -1;
  }
}
