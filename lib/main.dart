import 'dart:async';

import 'package:argus/gradient_container.dart';
import 'package:argus/map.dart';
import 'package:argus/plot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:latlong2/latlong.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:argus/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';
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
  final logger = Logger(printer: SimplePrinter());

  List<FlutterMissionNode> _missionNodes = [
    const FlutterMissionNode.init(),
    const FlutterMissionNode.takeoff(altitude: 10.0),
    const FlutterMissionNode.land(),
    const FlutterMissionNode.end()
  ];

  CoreConnection? _connection;
  Stream<PositionTriple>? _posStream;
  Stream<int>? _stepStream;
  Stream<bool>? _onlineStream;
  Stream<FlutterControlResponse>? _controlStream;
  bool _online = false;
  final _mapController = MapController();
  final _plotController = PlotController();
  dynamic Function(LatLng)? getMapLocation;

  void _connect() {
    if (_connection == null) {
      CoreConnection.init(machine: "sim").then((conn) async {
        _connection = conn;
        _posStream = (await conn.getPos()).asBroadcastStream();
        _onlineStream = (await conn.getOnline()).asBroadcastStream();
        _stepStream = (await conn.getStep()).asBroadcastStream();
        _controlStream = (await conn.getControl()).asBroadcastStream();
        setState(() {});

        _posStream!.first.then((p) {
          logger.i("Re-Centering Map");
          setState(() {
            _mapController.move(LatLng(p.x, p.y), _mapController.camera.zoom);
          });
        }, onError: (_) => ());

        _posStream!.forEach((p) {
          _plotController.push(AltPoint(DateTime.now(), p.z));
        });

        _onlineStream!.forEach((o) async {
          if (o && !_online) {
            logger.i("Fetching Mission Plan");
            conn.sendControl(req: FlutterControlRequest.fetchMissionPlan);
          }

          _online = o;
        });

        _controlStream!.forEach((p) {
          p.map(sendMissionPlan: (smp) {
            setState(() {
              logger.i("Mission Plan Received");
              _missionNodes = smp.field0.toList();
            });
          });
        });
      });
    }
  }

  void _addNode(FlutterMissionNode node) {
    setState(() {
      if (_missionNodes.length > 2 &&
          _missionNodes[_missionNodes.length - 2] is FlutterMissionNode_Land) {
        _missionNodes.insert(_missionNodes.length - 2, node);
      } else {
        _missionNodes.insert(_missionNodes.length - 1, node);
      }
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

  bool isUnlocked(AsyncSnapshot<int> snap) {
    return snap.data == null || snap.data! == -1;
  }

  @override
  Widget build(BuildContext context) {
    _connect();
    return Scaffold(
        appBar: AppBar(
          leading: StreamBuilder<bool>(
              stream: _onlineStream,
              builder: (context, onlineSnapshot) {
                return StreamBuilder<int>(
                    stream: _stepStream,
                    builder: (context, stepSnapshot) {
                      VehicleState vehicleState;
                      if (onlineSnapshot.hasData && onlineSnapshot.data!) {
                        if (stepSnapshot.hasData && stepSnapshot.data! > 0) {
                          vehicleState = VehicleState.flying;
                        } else if (stepSnapshot.hasData &&
                            stepSnapshot.data! == 0) {
                          vehicleState = VehicleState.ready;
                        } else {
                          vehicleState = VehicleState.online;
                        }
                      } else {
                        vehicleState = VehicleState.offline;
                      }
                      return GradientContainer(
                        state: vehicleState,
                      );
                    });
              }),
          leadingWidth: 120,
          actions: const [
            Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(
                child: Text(
                  "Node: $machine",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
          centerTitle: true,
          notificationPredicate: (notification) => false,
          title: const Text('Argus Flight Management'),
        ),
        body: Column(
          children: [
            Expanded(
              flex: 3,
              child: MainMapWidget(
                controller: _mapController,
                posStream: _posStream,
                missionNodes: _missionNodes,
                getLocation: getMapLocation,
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
                    child: StreamBuilder<int>(
                        stream: _stepStream,
                        builder: (context, snapshot) {
                          bool isMe(AsyncSnapshot<int> snap, index) {
                            return (snap.data?.toInt() == index);
                          }

                          return ReorderableListView.builder(
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

                              return ReorderableDragStartListener(
                                  index: index,
                                  key: ValueKey(node),
                                  enabled: !_isBedrock(index) &&
                                      isUnlocked(snapshot),
                                  child: ListTile(
                                    leading: _getIconForNode(node),
                                    title: Text(_getTextForNode(node)),
                                    textColor: isMe(snapshot, index)
                                        ? Colors.orange
                                        : null,
                                    titleTextStyle: isMe(snapshot, index)
                                        ? const TextStyle(
                                            fontWeight: FontWeight.bold)
                                        : const TextStyle(),
                                    trailing: !_isBedrock(index) &&
                                            isUnlocked(snapshot)
                                        ? IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () => _removeNode(index),
                                          )
                                        : null,
                                  ));
                            },
                          );
                        }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<bool>(
                  stream: _onlineStream,
                  builder: (context, onlineSnapshot) {
                    return StreamBuilder<int>(
                        stream: _stepStream,
                        builder: (context, stepSnapshot) {
                          return ElevatedButton.icon(
                            label: const Text('Send Mission'),
                            icon: const Icon(Icons.check),
                            onPressed: (onlineSnapshot.hasData &&
                                    onlineSnapshot.data! &&
                                    isUnlocked(stepSnapshot))
                                ? () async {
                                    if (_connection != null) {
                                      _connection!.sendControl(
                                          req: FlutterControlRequest
                                              .fetchMissionPlan);
                                      await _connection!
                                          .sendMissionPlan(plan: _missionNodes);
                                    }
                                  }
                                : null,
                          );
                        });
                  }),
            ),
          ],
        ),
        floatingActionButton: StreamBuilder<int>(
            stream: _stepStream,
            builder: (context, snapshot) {
              return SpeedDial(
                visible: isUnlocked(snapshot),
                icon: Icons.add,
                childMargin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                children: [
                  SpeedDialChild(
                      child: const Icon(Icons.flight_land),
                      backgroundColor: Colors.green,
                      label: 'Land',
                      labelStyle: const TextStyle(fontSize: 18.0),
                      onTap: () => _addNode(const FlutterMissionNode.land()),
                      shape: const CircleBorder()),
                  SpeedDialChild(
                      child: const Icon(Icons.flight_takeoff),
                      backgroundColor: Colors.green,
                      label: 'Takeoff',
                      labelStyle: const TextStyle(fontSize: 18.0),
                      onTap: () => _addNode(
                          const FlutterMissionNode.takeoff(altitude: 5.0)),
                      shape: const CircleBorder()),
                  SpeedDialChild(
                      child: const Icon(Icons.timer),
                      backgroundColor: Colors.orange,
                      label: 'Delay',
                      labelStyle: const TextStyle(fontSize: 18.0),
                      onTap: () =>
                          _addNode(const FlutterMissionNode.delay(5.0)),
                      shape: const CircleBorder()),
                  SpeedDialChild(
                      child: const Icon(Icons.gps_fixed),
                      backgroundColor: Colors.indigo,
                      label: 'Offset Waypoint',
                      labelStyle: const TextStyle(fontSize: 18.0),
                      onTap: () {
                        showModalBottomSheet<FlutterWaypoint_LocalOffset>(
                            context: context,
                            isScrollControlled: true,
                            builder: (BuildContext context) {
                              return const SizedBox(
                                height: 250,
                                child: Center(
                                  child: LocalOffsetForm(),
                                ),
                              );
                            }).then((wp) {
                          if (wp != null) {
                            _addNode(FlutterMissionNode.waypoint(wp));
                          }
                        });
                      },
                      shape: const CircleBorder()),
                  SpeedDialChild(
                      child: const Icon(Icons.gps_fixed),
                      backgroundColor: Colors.red,
                      label: 'GPS Waypoint',
                      labelStyle: const TextStyle(fontSize: 18.0),
                      onTap: () {
                        setState(() {
                          getMapLocation = (ll) {
                            _addNode(FlutterMissionNode.waypoint(
                                FlutterWaypoint.globalRelativeHeight(
                                    lat: ll.latitude,
                                    lon: ll.longitude,
                                    heightDiff: 0.0)));
                            setState(() {
                              getMapLocation = null;
                            });
                          };
                        });
                      },
                      shape: const CircleBorder()),
                ],
              );
            }));
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

class LocalOffsetForm extends StatefulWidget {
  const LocalOffsetForm({super.key});

  @override
  State<LocalOffsetForm> createState() => _LocalOffsetFormState();
}

class _LocalOffsetFormState extends State<LocalOffsetForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _zController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Column(
        children: [
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: const Text('Enter Local Offset'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop(FlutterWaypoint.localOffset(
                        double.parse(_xController.text),
                        double.parse(_yController.text),
                        double.parse(_zController.text)));
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _xController,
                    decoration: const InputDecoration(
                      labelText: 'X (in meters)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value for X';
                      }
                      final doubleValue = double.tryParse(value);
                      if (doubleValue == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _yController,
                    decoration: const InputDecoration(
                      labelText: 'Y (in meters)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value for Y';
                      }
                      final doubleValue = double.tryParse(value);
                      if (doubleValue == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _zController,
                    decoration: const InputDecoration(
                      labelText: 'Z (in meters)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value for Z';
                      }
                      final doubleValue = double.tryParse(value);
                      if (doubleValue == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
