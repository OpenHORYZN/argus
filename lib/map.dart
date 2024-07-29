import 'package:argus/src/rust/api/mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MainMapWidget extends StatefulWidget {
  final MapController controller;
  final Stream<PositionTriple>? posStream;
  final List<FlutterMissionNode> missionNodes;
  final dynamic Function(LatLng)? getLocation;

  const MainMapWidget(
      {super.key,
      required this.controller,
      required this.posStream,
      required this.missionNodes,
      this.getLocation});

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
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
          initialZoom: currentZoom,
          onTap: (widget.getLocation != null)
              ? (event, point) => widget.getLocation!(point)
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
        StreamBuilder<PositionTriple>(
            stream: widget.posStream,
            builder: (context, snapshot) {
              return MarkerLayer(
                markers: widget.missionNodes
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
                            height: 60.0,
                            width: 60.0,
                            point: LatLng(snapshot.data!.x, snapshot.data!.y),
                            child: Transform.rotate(
                              angle: 0.0,
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
            }),
        Positioned(
          right: 10.0,
          top: 10.0,
          child: ZoomButtons(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
          ),
        ),
        if (widget.getLocation != null)
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
