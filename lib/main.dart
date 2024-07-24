import 'dart:async';

import 'package:argus/gradient_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:argus/src/rust/frb_generated.dart';
import 'package:window_manager/window_manager.dart';

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
  final List<FlutterMissionNode> _missionNodes = [
    const FlutterMissionNode.init(),
    const FlutterMissionNode.takeoff(altitude: 10.0),
    const FlutterMissionNode.waypoint(FlutterWaypoint.globalRelativeHeight(
        lat: 47.397971, lon: 8.546164, heightDiff: 5.0)),
    const FlutterMissionNode.land(),
    const FlutterMissionNode.end()
  ];

  CoreConnection? _connection;
  Stream<PositionTriple>? _posStream;
  Stream<BigInt>? _stepStream;
  Stream<bool>? _onlineStream;
  final _mapController = MapController();

  void _connect() {
    if (_connection == null) {
      CoreConnection.init().then((conn) async {
        _connection = conn;
        _posStream = (await conn.getPos()).asBroadcastStream();
        _onlineStream = (await conn.getOnline()).asBroadcastStream();
        _stepStream = (await conn.getStep()).asBroadcastStream();
        setState(() {});

        _posStream!.first.then((p) {
          setState(() {
            _mapController.move(LatLng(p.x, p.y), 10.0);
          });
        }, onError: (_) => ());
      });
    }
  }

  void _addNode(FlutterMissionNode node) {
    setState(() {
      _missionNodes.insert(_missionNodes.length - 1, node);
    });
  }

  void _removeNode(int index) {
    setState(() {
      _missionNodes.removeAt(index);
    });
  }

  bool _isBedrock(int index) {
    return _missionNodes[index] is FlutterMissionNode_Init ||
        _missionNodes[index] is FlutterMissionNode_End;
  }

  @override
  Widget build(BuildContext context) {
    _connect();
    return Scaffold(
      appBar: AppBar(
        leading: StreamBuilder<bool>(
            stream: _onlineStream,
            builder: (context, snapshot) {
              return GradientContainer(
                connected: snapshot.data ?? false,
              );
            }),
        leadingWidth: 120,
        centerTitle: true,
        notificationPredicate: (notification) => false,
        title: const Text('Argus Flight Management'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                backgroundColor: Colors.black,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://mt.google.com/vt/lyrs=s&x={x}&y={y}&z={z}",
                ),
                StreamBuilder<PositionTriple>(
                    stream: _posStream,
                    builder: (context, snapshot) {
                      return MarkerLayer(
                        markers: _missionNodes
                                .whereType<FlutterMissionNode_Waypoint>()
                                .map((node) {
                                  final waypoint = node.field0;
                                  LatLng? latLng;
                                  waypoint.when(
                                    localOffset: (x, y, z) {
                                      // Assuming you have a way to translate local offset to LatLng
                                    },
                                    globalFixedHeight: (lat, lon, alt) {
                                      latLng = LatLng(lat, lon);
                                    },
                                    globalRelativeHeight:
                                        (lat, lon, heightDiff) {
                                      latLng = LatLng(lat, lon);
                                    },
                                  );
                                  if (latLng != null) {
                                    return Marker(
                                      width: 80.0,
                                      height: 80.0,
                                      point: latLng!,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Color.fromARGB(255, 255, 0, 0),
                                        size: 50.0,
                                      ),
                                    );
                                  }
                                  return null;
                                })
                                .whereType<Marker>()
                                .toList() +
                            [
                              if (snapshot.hasData)
                                Marker(
                                    point: LatLng(
                                        snapshot.data!.x, snapshot.data!.y),
                                    child: const Icon(
                                      Icons.airplanemode_active,
                                      size: 50.0,
                                    ))
                            ],
                      );
                    }),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: ReorderableListView.builder(
              itemCount: _missionNodes.length,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (_isBedrock(oldIndex)) {
                    return;
                  }

                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }

                  if (_isBedrock(newIndex)) {
                    return;
                  }

                  final it = _missionNodes.removeAt(oldIndex);
                  _missionNodes.insert(newIndex, it);
                });
              },
              itemBuilder: (context, index) {
                final node = _missionNodes[index];
                bool isMe(AsyncSnapshot<BigInt> snap, index) {
                  return (snap.data?.toInt() == index);
                }

                return ReorderableDragStartListener(
                  index: index,
                  key: ValueKey(node),
                  enabled: !_isBedrock(index),
                  child: StreamBuilder<BigInt>(
                      stream: _stepStream,
                      builder: (context, snapshot) {
                        return ListTile(
                          leading: _getIconForNode(node),
                          title: Text(_getTextForNode(node)),
                          textColor:
                              isMe(snapshot, index) ? Colors.orange : null,
                          titleTextStyle: isMe(snapshot, index)
                              ? const TextStyle(fontWeight: FontWeight.bold)
                              : const TextStyle(),
                          trailing: !_isBedrock(index)
                              ? IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeNode(index),
                                )
                              : null,
                        );
                      }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              label: const Text('Send Mission'),
              icon: const Icon(Icons.check),
              onPressed: () async {
                if (_connection != null) {
                  await _connection!.sendMissionPlan(plan: _missionNodes);
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => (),
        child: const Icon(Icons.add),
      ),
    );
  }

  Icon _getIconForNode(FlutterMissionNode node) {
    return node.map(
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
    return node.map(
        init: (_) => 'Init',
        takeoff: (_) => 'Takeoff',
        waypoint: (n) => 'Waypoint',
        delay: (n) => 'Delay (${n.field0} seconds)',
        land: (_) => 'Land',
        end: (_) => 'End',
        findSafeSpot: (_) => 'Find Safe Spot',
        transition: (_) => 'Transition',
        precLand: (_) => 'Precision Land');
  }
}
