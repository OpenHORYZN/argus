import 'dart:async';

import 'package:argus/create_node/local_offset.dart';
import 'package:argus/map.dart';
import 'package:argus/mission_plan.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';

class MainFAB extends StatelessWidget {
  final bool _paused;
  final Stream<int>? _stepStream;
  final CoreConnection? _connection;

  const MainFAB({
    super.key,
    required bool paused,
    required Stream<int>? stepStream,
    required CoreConnection? connection,
  })  : _paused = paused,
        _stepStream = stepStream,
        _connection = connection;

  @override
  Widget build(BuildContext context) {
    return Consumer<MissionPlanList>(
      builder: (context, missionNodes, child) => StreamBuilder<int>(
          stream: _stepStream,
          builder: (context, snapshot) {
            bool canPause(AsyncSnapshot<int> snap) {
              if (missionNodes.isUnlocked(snap)) {
                return false;
              }
              if (_paused) {
                return true;
              }
              var node = missionNodes.missionNodes[snap.data!];
              return node.item is! FlutterMissionItem_Init &&
                  node.item is! FlutterMissionItem_End &&
                  node.item is! FlutterMissionItem_Delay &&
                  node.item is! FlutterMissionItem_Land;
            }

            if (missionNodes.isUnlocked(snapshot)) {
              return Consumer<MapMeta>(
                builder: (context, mapMeta, child) => SpeedDial(
                  icon: Icons.add,
                  childMargin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                  children: [
                    SpeedDialChild(
                        child: const Icon(Icons.flight_land),
                        backgroundColor: Colors.green,
                        label: 'Land',
                        labelStyle: const TextStyle(fontSize: 18.0),
                        onTap: () => missionNodes.addNode(
                            FlutterMissionNode.random(
                                item: const FlutterMissionItem.land())),
                        shape: const CircleBorder()),
                    SpeedDialChild(
                        child: const Icon(Icons.flight_takeoff),
                        backgroundColor: Colors.green,
                        label: 'Takeoff',
                        labelStyle: const TextStyle(fontSize: 18.0),
                        onTap: () => missionNodes.addNode(
                            FlutterMissionNode.random(
                                item: const FlutterMissionItem.takeoff(
                                    altitude: 5.0))),
                        shape: const CircleBorder()),
                    SpeedDialChild(
                        child: const Icon(Icons.timer),
                        backgroundColor: Colors.orange,
                        label: 'Delay',
                        labelStyle: const TextStyle(fontSize: 18.0),
                        onTap: () => missionNodes.addNode(
                            FlutterMissionNode.random(
                                item: const FlutterMissionItem.delay(5.0))),
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
                              missionNodes.addNode(FlutterMissionNode.random(
                                  item: FlutterMissionItem.waypoint(wp)));
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
                          mapMeta.setGPSResult((ll) {
                            missionNodes.addNode(FlutterMissionNode.random(
                                item: FlutterMissionItem.waypoint(
                                    FlutterWaypoint.globalRelativeHeight(
                                        lat: ll.latitude,
                                        lon: ll.longitude,
                                        heightDiff: 0.0))));
                            mapMeta.setGPSResult(null);
                          });
                        },
                        shape: const CircleBorder()),
                  ],
                ),
              );
            } else {
              return Visibility(
                visible: canPause(snapshot),
                maintainAnimation: true,
                maintainState: true,
                child: FloatingActionButton(
                  onPressed: canPause(snapshot)
                      ? () async {
                          if (_connection != null) {
                            await _connection.sendControl(
                                req: FlutterControlRequest.pauseResume(
                                    !_paused));
                          }
                        }
                      : null,
                  backgroundColor: _paused ? Colors.green : Colors.orange,
                  child: Icon(_paused ? Icons.play_arrow : Icons.pause),
                ),
              );
            }
          }),
    );
  }
}
