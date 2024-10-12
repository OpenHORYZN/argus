// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.5.0.

// ignore_for_file: unused_import, unused_element, unnecessary_import, duplicate_ignore, invalid_use_of_internal_member, annotate_overrides, non_constant_identifier_names, curly_braces_in_flow_control_structures, prefer_const_literals_to_create_immutables, unused_field

// Static analysis wrongly picks the IO variant, thus ignore this
// ignore_for_file: argument_type_not_assignable

import 'api/mission.dart';
import 'dart:async';
import 'dart:convert';
import 'frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart';
import 'package:uuid/uuid.dart';

abstract class RustLibApiImplPlatform extends BaseApiImpl<RustLibWire> {
  RustLibApiImplPlatform({
    required super.handler,
    required super.wire,
    required super.generalizedFrbRustBinding,
    required super.portManager,
  });

  CrossPlatformFinalizerArg
      get rust_arc_decrement_strong_count_CoreConnectionPtr => wire
          .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection;

  @protected
  AnyhowException dco_decode_AnyhowException(dynamic raw);

  @protected
  CoreConnection
      dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          dynamic raw);

  @protected
  CoreConnection
      dco_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          dynamic raw);

  @protected
  CoreConnection
      dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          dynamic raw);

  @protected
  CoreConnection
      dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          dynamic raw);

  @protected
  RustStreamSink<bool> dco_decode_StreamSink_bool_Sse(dynamic raw);

  @protected
  RustStreamSink<double> dco_decode_StreamSink_f_64_Sse(dynamic raw);

  @protected
  RustStreamSink<FlutterControlResponse>
      dco_decode_StreamSink_flutter_control_response_Sse(dynamic raw);

  @protected
  RustStreamSink<int> dco_decode_StreamSink_i_32_Sse(dynamic raw);

  @protected
  RustStreamSink<PositionTriple> dco_decode_StreamSink_position_triple_Sse(
      dynamic raw);

  @protected
  String dco_decode_String(dynamic raw);

  @protected
  UuidValue dco_decode_Uuid(dynamic raw);

  @protected
  bool dco_decode_bool(dynamic raw);

  @protected
  FlutterControlRequest dco_decode_box_autoadd_flutter_control_request(
      dynamic raw);

  @protected
  FlutterMissionItem dco_decode_box_autoadd_flutter_mission_item(dynamic raw);

  @protected
  FlutterMissionParams dco_decode_box_autoadd_flutter_mission_params(
      dynamic raw);

  @protected
  FlutterMissionPlan dco_decode_box_autoadd_flutter_mission_plan(dynamic raw);

  @protected
  FlutterWaypoint dco_decode_box_autoadd_flutter_waypoint(dynamic raw);

  @protected
  double dco_decode_f_64(dynamic raw);

  @protected
  FlutterControlRequest dco_decode_flutter_control_request(dynamic raw);

  @protected
  FlutterControlResponse dco_decode_flutter_control_response(dynamic raw);

  @protected
  FlutterMissionItem dco_decode_flutter_mission_item(dynamic raw);

  @protected
  FlutterMissionNode dco_decode_flutter_mission_node(dynamic raw);

  @protected
  FlutterMissionParams dco_decode_flutter_mission_params(dynamic raw);

  @protected
  FlutterMissionPlan dco_decode_flutter_mission_plan(dynamic raw);

  @protected
  FlutterVector3 dco_decode_flutter_vector_3(dynamic raw);

  @protected
  FlutterWaypoint dco_decode_flutter_waypoint(dynamic raw);

  @protected
  int dco_decode_i_32(dynamic raw);

  @protected
  List<FlutterMissionNode> dco_decode_list_flutter_mission_node(dynamic raw);

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw);

  @protected
  PositionTriple dco_decode_position_triple(dynamic raw);

  @protected
  int dco_decode_u_8(dynamic raw);

  @protected
  void dco_decode_unit(dynamic raw);

  @protected
  BigInt dco_decode_usize(dynamic raw);

  @protected
  AnyhowException sse_decode_AnyhowException(SseDeserializer deserializer);

  @protected
  CoreConnection
      sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          SseDeserializer deserializer);

  @protected
  CoreConnection
      sse_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          SseDeserializer deserializer);

  @protected
  CoreConnection
      sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          SseDeserializer deserializer);

  @protected
  CoreConnection
      sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          SseDeserializer deserializer);

  @protected
  RustStreamSink<bool> sse_decode_StreamSink_bool_Sse(
      SseDeserializer deserializer);

  @protected
  RustStreamSink<double> sse_decode_StreamSink_f_64_Sse(
      SseDeserializer deserializer);

  @protected
  RustStreamSink<FlutterControlResponse>
      sse_decode_StreamSink_flutter_control_response_Sse(
          SseDeserializer deserializer);

  @protected
  RustStreamSink<int> sse_decode_StreamSink_i_32_Sse(
      SseDeserializer deserializer);

  @protected
  RustStreamSink<PositionTriple> sse_decode_StreamSink_position_triple_Sse(
      SseDeserializer deserializer);

  @protected
  String sse_decode_String(SseDeserializer deserializer);

  @protected
  UuidValue sse_decode_Uuid(SseDeserializer deserializer);

  @protected
  bool sse_decode_bool(SseDeserializer deserializer);

  @protected
  FlutterControlRequest sse_decode_box_autoadd_flutter_control_request(
      SseDeserializer deserializer);

  @protected
  FlutterMissionItem sse_decode_box_autoadd_flutter_mission_item(
      SseDeserializer deserializer);

  @protected
  FlutterMissionParams sse_decode_box_autoadd_flutter_mission_params(
      SseDeserializer deserializer);

  @protected
  FlutterMissionPlan sse_decode_box_autoadd_flutter_mission_plan(
      SseDeserializer deserializer);

  @protected
  FlutterWaypoint sse_decode_box_autoadd_flutter_waypoint(
      SseDeserializer deserializer);

  @protected
  double sse_decode_f_64(SseDeserializer deserializer);

  @protected
  FlutterControlRequest sse_decode_flutter_control_request(
      SseDeserializer deserializer);

  @protected
  FlutterControlResponse sse_decode_flutter_control_response(
      SseDeserializer deserializer);

  @protected
  FlutterMissionItem sse_decode_flutter_mission_item(
      SseDeserializer deserializer);

  @protected
  FlutterMissionNode sse_decode_flutter_mission_node(
      SseDeserializer deserializer);

  @protected
  FlutterMissionParams sse_decode_flutter_mission_params(
      SseDeserializer deserializer);

  @protected
  FlutterMissionPlan sse_decode_flutter_mission_plan(
      SseDeserializer deserializer);

  @protected
  FlutterVector3 sse_decode_flutter_vector_3(SseDeserializer deserializer);

  @protected
  FlutterWaypoint sse_decode_flutter_waypoint(SseDeserializer deserializer);

  @protected
  int sse_decode_i_32(SseDeserializer deserializer);

  @protected
  List<FlutterMissionNode> sse_decode_list_flutter_mission_node(
      SseDeserializer deserializer);

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  PositionTriple sse_decode_position_triple(SseDeserializer deserializer);

  @protected
  int sse_decode_u_8(SseDeserializer deserializer);

  @protected
  void sse_decode_unit(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_usize(SseDeserializer deserializer);

  @protected
  void sse_encode_AnyhowException(
      AnyhowException self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          CoreConnection self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          CoreConnection self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          CoreConnection self, SseSerializer serializer);

  @protected
  void
      sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          CoreConnection self, SseSerializer serializer);

  @protected
  void sse_encode_StreamSink_bool_Sse(
      RustStreamSink<bool> self, SseSerializer serializer);

  @protected
  void sse_encode_StreamSink_f_64_Sse(
      RustStreamSink<double> self, SseSerializer serializer);

  @protected
  void sse_encode_StreamSink_flutter_control_response_Sse(
      RustStreamSink<FlutterControlResponse> self, SseSerializer serializer);

  @protected
  void sse_encode_StreamSink_i_32_Sse(
      RustStreamSink<int> self, SseSerializer serializer);

  @protected
  void sse_encode_StreamSink_position_triple_Sse(
      RustStreamSink<PositionTriple> self, SseSerializer serializer);

  @protected
  void sse_encode_String(String self, SseSerializer serializer);

  @protected
  void sse_encode_Uuid(UuidValue self, SseSerializer serializer);

  @protected
  void sse_encode_bool(bool self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_flutter_control_request(
      FlutterControlRequest self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_flutter_mission_item(
      FlutterMissionItem self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_flutter_mission_params(
      FlutterMissionParams self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_flutter_mission_plan(
      FlutterMissionPlan self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_flutter_waypoint(
      FlutterWaypoint self, SseSerializer serializer);

  @protected
  void sse_encode_f_64(double self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_control_request(
      FlutterControlRequest self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_control_response(
      FlutterControlResponse self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_mission_item(
      FlutterMissionItem self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_mission_node(
      FlutterMissionNode self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_mission_params(
      FlutterMissionParams self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_mission_plan(
      FlutterMissionPlan self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_vector_3(
      FlutterVector3 self, SseSerializer serializer);

  @protected
  void sse_encode_flutter_waypoint(
      FlutterWaypoint self, SseSerializer serializer);

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_list_flutter_mission_node(
      List<FlutterMissionNode> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_strict(
      Uint8List self, SseSerializer serializer);

  @protected
  void sse_encode_position_triple(
      PositionTriple self, SseSerializer serializer);

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer);

  @protected
  void sse_encode_unit(void self, SseSerializer serializer);

  @protected
  void sse_encode_usize(BigInt self, SseSerializer serializer);
}

// Section: wire_class

class RustLibWire implements BaseWire {
  RustLibWire.fromExternalLibrary(ExternalLibrary lib);

  void rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          int ptr) =>
      wasmModule
          .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
              ptr);

  void rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          int ptr) =>
      wasmModule
          .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
              ptr);
}

@JS('wasm_bindgen')
external RustLibWasmModule get wasmModule;

@JS()
@anonymous
extension type RustLibWasmModule._(JSObject _) implements JSObject {
  external void
      rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          int ptr);

  external void
      rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCoreConnection(
          int ptr);
}
