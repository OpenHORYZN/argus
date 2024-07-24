// This file is automatically generated, so please do not edit it.
// Generated by `flutter_rust_bridge`@ 2.1.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:freezed_annotation/freezed_annotation.dart' hide protected;
part 'mission.freezed.dart';

// These functions are ignored because they are not marked as `pub`: `watch_stream`
// These function are ignored because they are on traits that is not defined in current crate (put an empty `#[frb]` on it to unignore): `clone`, `fmt`, `from`, `from`

// Rust type: RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CoreConnection>>
abstract class CoreConnection implements RustOpaqueInterface {
  Future<Stream<bool>> getOnline();

  Future<Stream<PositionTriple>> getPos();

  Future<Stream<BigInt>> getStep();

  static Future<CoreConnection> init() =>
      RustLib.instance.api.crateApiMissionCoreConnectionInit();

  Future<void> sendMissionPlan({required List<FlutterMissionNode> plan});
}

@freezed
sealed class FlutterMissionNode with _$FlutterMissionNode {
  const FlutterMissionNode._();

  const factory FlutterMissionNode.init() = FlutterMissionNode_Init;
  const factory FlutterMissionNode.takeoff({
    required double altitude,
  }) = FlutterMissionNode_Takeoff;
  const factory FlutterMissionNode.waypoint(
    FlutterWaypoint field0,
  ) = FlutterMissionNode_Waypoint;
  const factory FlutterMissionNode.delay(
    double field0,
  ) = FlutterMissionNode_Delay;
  const factory FlutterMissionNode.findSafeSpot() =
      FlutterMissionNode_FindSafeSpot;
  const factory FlutterMissionNode.transition() = FlutterMissionNode_Transition;
  const factory FlutterMissionNode.land() = FlutterMissionNode_Land;
  const factory FlutterMissionNode.precLand() = FlutterMissionNode_PrecLand;
  const factory FlutterMissionNode.end() = FlutterMissionNode_End;
}

@freezed
sealed class FlutterWaypoint with _$FlutterWaypoint {
  const FlutterWaypoint._();

  const factory FlutterWaypoint.localOffset(
    double field0,
    double field1,
    double field2,
  ) = FlutterWaypoint_LocalOffset;
  const factory FlutterWaypoint.globalFixedHeight({
    required double lat,
    required double lon,
    required double alt,
  }) = FlutterWaypoint_GlobalFixedHeight;
  const factory FlutterWaypoint.globalRelativeHeight({
    required double lat,
    required double lon,
    required double heightDiff,
  }) = FlutterWaypoint_GlobalRelativeHeight;
}

class PositionTriple {
  final double x;
  final double y;
  final double z;

  const PositionTriple({
    required this.x,
    required this.y,
    required this.z,
  });

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionTriple &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;
}
