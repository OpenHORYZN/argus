import 'package:argus/mission_plan/plan.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

class MainMapWidget extends StatefulWidget {
  final MapController controller;
  final Stream<PositionTriple>? posStream;
  final Stream<double>? yawStream;

  const MainMapWidget({
    super.key,
    required this.controller,
    required this.posStream,
    required this.yawStream,
  });

  @override
  State<MainMapWidget> createState() => _MainMapWidgetState();
}

class _MainMapWidgetState extends State<MainMapWidget> {
  double currentZoom = 20.0;
  void _zoomIn() {
    setState(() {
      currentZoom++;
      widget.controller.move(widget.controller.camera.center, currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      currentZoom--;
      widget.controller.move(widget.controller.camera.center, currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapMeta>(
      builder: (context, meta, child) => FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
            initialZoom: currentZoom,
            onTap: (meta.gpsResult != null)
                ? (event, point) => meta.gpsResult!(point)
                : null,
            backgroundColor: Colors.black,
            interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all &
                    ~InteractiveFlag.rotate &
                    ~InteractiveFlag.pinchMove &
                    ~InteractiveFlag.doubleTapZoom,
                enableMultiFingerGestureRace: true,
                pinchZoomThreshold: 0.0,
                pinchZoomWinGestures: MultiFingerGesture.pinchZoom,
                cursorKeyboardRotationOptions: CursorKeyboardRotationOptions(
                  isKeyTrigger: (key) => false,
                ))),
        children: [
          TileLayer(
            urlTemplate: "https://mt.google.com/vt/lyrs=s&x={x}&y={y}&z={z}",
          ),
          Consumer<MissionPlanState>(
            builder: (context, missionNodes, child) => StreamBuilder<
                    PositionTriple>(
                stream: widget.posStream,
                builder: (posContext, posSnapshot) {
                  return StreamBuilder<double>(
                      stream: widget.yawStream,
                      builder: (yawContext, yawSnapshot) {
                        return MarkerLayer(
                          markers: missionNodes.missionNodes
                                  .map((node) => node.item)
                                  .whereType<FlutterMissionItem_Waypoint>()
                                  .mapIndexed((index, node) {
                                    final waypoint = node.field0;
                                    LatLng? latLng;
                                    waypoint.when(
                                      localOffset: (x, y, z) {},
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
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            const Icon(
                                              Icons.location_pin,
                                              color: Color.fromARGB(
                                                  255, 255, 0, 0),
                                              size: 50.0,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10.0),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                    3.0), // Space between the text and the border
                                                decoration: BoxDecoration(
                                                  color: Colors
                                                      .white, // Circle color
                                                  shape: BoxShape
                                                      .circle, // Circular shape
                                                  border: Border.all(
                                                    color: Colors
                                                        .black, // Border color
                                                    width: 1.0, // Border width
                                                  ),
                                                ),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 12.0,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return null;
                                  })
                                  .whereType<Marker>()
                                  .toList() +
                              [
                                if (posSnapshot.hasData)
                                  Marker(
                                      height: 60.0,
                                      width: 60.0,
                                      point: LatLng(posSnapshot.data!.x,
                                          posSnapshot.data!.y),
                                      child: Transform.rotate(
                                        angle: yawSnapshot.hasData
                                            ? yawSnapshot.data!
                                            : 0.0,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white60),
                                          child: const Icon(
                                            Icons.local_airport,
                                            size: 40.0,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ))
                              ],
                        );
                      });
                }),
          ),
          Positioned(
            right: 10.0,
            top: 10.0,
            child: ZoomButtons(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),
          if (meta.gpsResult != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Text(
                    'Click the map to select a location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ZoomButtons extends StatelessWidget {
  final Function() onZoomIn;
  final Function() onZoomOut;

  const ZoomButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'zoom_in',
          onPressed: onZoomIn,
          mini: true,
          child: const Icon(Icons.zoom_in),
        ),
        const SizedBox(height: 8.0),
        FloatingActionButton(
          heroTag: 'zoom_out',
          onPressed: onZoomOut,
          mini: true,
          child: const Icon(Icons.zoom_out),
        ),
      ],
    );
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
