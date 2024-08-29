import 'dart:async';

import 'package:argus/fab.dart';
import 'package:argus/map.dart';
import 'package:argus/mission_plan/plan.dart';
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

  void _connect(MissionPlanState missionPlan) {
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
            missionPlan.setList(smp.field0.nodes.toList());
            missionPlan.setParams(smp.field0.params);
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
            create: (context) => MissionPlanState.withConnect(_connect)),
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
                      child: MissionPlanView(
                        stepStream: _stepStream,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<MissionPlanState>(
                  builder: (context, missionPlan, child) => StreamBuilder<bool>(
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
                                        missionPlan.isUnlocked(stepSnapshot))
                                    ? () async {
                                        if (_connection != null) {
                                          _connection!.sendControl(
                                              req: const FlutterControlRequest
                                                  .fetchMissionPlan());
                                          await _connection!.sendMissionPlan(
                                              plan: FlutterMissionPlan(
                                                  id: uuid.v4obj(),
                                                  nodes:
                                                      missionPlan.missionNodes,
                                                  params: missionPlan.params));
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
}
