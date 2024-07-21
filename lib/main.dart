import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:argus/src/rust/frb_generated.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setAsFrameless();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MissionPlannerPage(),
      darkTheme: ThemeData.dark(),
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
        lat: 47.397971, lon: 8.546164, heightDiff: -5.0)),
    const FlutterMissionNode.land(),
    const FlutterMissionNode.end()
  ];

  void _addNode(FlutterMissionNode node) {
    setState(() {
      _missionNodes.insert(_missionNodes.length - 1, node);
    });
  }

  void _removeNode(int index) {
    setState(() {
      if (_missionNodes.length > 3) {
        _missionNodes.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Center(child: Text('Argus Flight Management'))),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://mt.google.com/vt/lyrs=y&x={x}&y={y}&z={z}",
                ),
                MarkerLayer(
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
                          globalRelativeHeight: (lat, lon, heightDiff) {
                            latLng = LatLng(lat, lon);
                          },
                        );
                        if (latLng != null) {
                          return Marker(
                            width: 80.0,
                            height: 80.0,
                            point: latLng!,
                            child: const Icon(
                              Icons.place,
                              color: Colors.red,
                              size: 40.0,
                            ),
                          );
                        }
                        return null;
                      })
                      .whereType<Marker>()
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _missionNodes.length,
              itemBuilder: (context, index) {
                final node = _missionNodes[index];
                return ListTile(
                  leading: _getIconForNode(node),
                  title: Text(_getTextForNode(node)),
                  trailing: index != 0 && index != _missionNodes.length - 1
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeNode(index),
                        )
                      : null,
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
                await sendMissionPlan(plan: _missionNodes);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNodeDialog(context),
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

  void _showAddNodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Mission Node'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: const Text('Takeoff'),
                onTap: () {
                  Navigator.pop(context);
                  _showTakeoffDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Local Offset Waypoint'),
                onTap: () {
                  Navigator.pop(context);
                  _showLocalOffsetWaypointDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Global Relative Height Waypoint'),
                onTap: () {
                  Navigator.pop(context);
                  _showGlobalRelativeHeightWaypointDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Delay'),
                onTap: () {
                  Navigator.pop(context);
                  _showDelayDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flight_land),
                title: const Text('Land'),
                onTap: () {
                  Navigator.pop(context);
                  _addNode(const FlutterMissionNode.land());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTakeoffDialog(BuildContext context) {
    final TextEditingController altitudeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Takeoff Settings'),
          content: TextField(
            controller: altitudeController,
            decoration: const InputDecoration(labelText: 'Altitude'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final altitude =
                    double.tryParse(altitudeController.text) ?? 10.0;
                _addNode(FlutterMissionNode.takeoff(altitude: altitude));
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showLocalOffsetWaypointDialog(BuildContext context) {
    final TextEditingController xController = TextEditingController();
    final TextEditingController yController = TextEditingController();
    final TextEditingController zController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Local Offset Waypoint Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: xController,
                decoration: const InputDecoration(labelText: 'X Offset'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: yController,
                decoration: const InputDecoration(labelText: 'Y Offset'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: zController,
                decoration: const InputDecoration(labelText: 'Z Offset'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final x = double.tryParse(xController.text) ?? 0.0;
                final y = double.tryParse(yController.text) ?? 0.0;
                final z = double.tryParse(zController.text) ?? 0.0;
                _addNode(FlutterMissionNode.waypoint(
                    FlutterWaypoint.localOffset(x, y, z)));
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showGlobalRelativeHeightWaypointDialog(BuildContext context) {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lonController = TextEditingController();
    final TextEditingController heightDiffController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Global Relative Height Waypoint Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: heightDiffController,
                decoration:
                    const InputDecoration(labelText: 'Height Difference'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final lat = double.tryParse(latController.text) ?? 0.0;
                final lon = double.tryParse(lonController.text) ?? 0.0;
                final heightDiff =
                    double.tryParse(heightDiffController.text) ?? 0.0;
                _addNode(FlutterMissionNode.waypoint(
                    FlutterWaypoint.globalRelativeHeight(
                        lat: lat, lon: lon, heightDiff: heightDiff)));
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showDelayDialog(BuildContext context) {
    final TextEditingController secondsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delay Settings'),
          content: TextField(
            controller: secondsController,
            decoration: const InputDecoration(labelText: 'Seconds'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final seconds = int.tryParse(secondsController.text) ?? 0;
                _addNode(FlutterMissionNode.delay(seconds.toDouble()));
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
