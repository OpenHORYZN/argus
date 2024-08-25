import 'dart:collection';

import 'package:argus/edit_node/delay.dart';
import 'package:argus/edit_node/takeoff.dart';
import 'package:argus/src/rust/api/mission.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class MissionPlanView extends StatefulWidget {
  final Stream<int>? stepStream;
  const MissionPlanView({super.key, required this.stepStream});

  @override
  State<MissionPlanView> createState() => _MissionPlanViewState();
}

class _MissionPlanViewState extends State<MissionPlanView> {
  bool lastLock = false;
  HashMap<UuidValue, bool> expansionState = HashMap();

  @override
  Widget build(BuildContext context) {
    return Consumer<MissionPlanList>(
      builder: (context, missionNodes, child) => StreamBuilder<int>(
          stream: widget.stepStream,
          builder: (context, snapshot) {
            bool isSelected(index) {
              return (snapshot.data?.toInt() == index);
            }

            bool isActive(index) {
              return !missionNodes.isBedrock(index) &&
                  missionNodes.isUnlocked(snapshot);
            }

            bool isExpandable(index) {
              var item = missionNodes.missionNodes[index].item;
              return isActive(index) &&
                  item is! FlutterMissionItem_Land &&
                  item is! FlutterMissionItem_Waypoint;
            }

            var result = ReorderableListView.builder(
              itemCount: missionNodes.length,
              buildDefaultDragHandles: false,
              onReorder: missionNodes.reorder,
              itemBuilder: (context, index) {
                final node = missionNodes.missionNodes[index];

                return ReorderableDragStartListener(
                    index: index,
                    key: ValueKey(node.id),
                    enabled:
                        isActive(index) && !(expansionState[node.id] ?? false),
                    child: Theme(
                      data: _ignoreDisabled(context),
                      child: ExpansionTile(
                        enabled: isExpandable(index),
                        leading: _getIconForNode(node),
                        title: Text(
                          _getTextForNode(node),
                          style: isSelected(index)
                              ? TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected(index)
                                      ? Colors.orange
                                      : Colors.white)
                              : const TextStyle(),
                        ),
                        trailing: isActive(index)
                            ? IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => missionNodes.removeNode(index),
                              )
                            : const SizedBox.shrink(),
                        onExpansionChanged: (value) {
                          setState(() {
                            expansionState[node.id] = value;
                          });
                        },
                        children: ([
                          Builder(builder: (context) {
                            var controller =
                                ExpansionTileController.of(context);
                            if (controller.isExpanded &&
                                !missionNodes.isUnlocked(snapshot)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                controller.collapse();
                              });
                            }
                            return const SizedBox.shrink();
                          }),
                          node.item.map(
                              init: (_) => null,
                              takeoff: (t) => Builder(builder: (context) {
                                    return TakeoffEdit(
                                        onSubmit: (alt) {
                                          missionNodes.replaceNode(
                                              index,
                                              FlutterMissionNode(
                                                  id: node.id,
                                                  item: FlutterMissionItem
                                                      .takeoff(altitude: alt)));
                                          ExpansionTileController.of(context)
                                              .collapse();
                                        },
                                        initialAltitude: t.altitude);
                                  }),
                              waypoint: (_) => null,
                              delay: (d) => Builder(builder: (context) {
                                    return DelayEdit(
                                      onSubmit: (d) {
                                        missionNodes.replaceNode(
                                            index,
                                            FlutterMissionNode(
                                                id: node.id,
                                                item: FlutterMissionItem.delay(
                                                    d)));
                                        ExpansionTileController.of(context)
                                            .collapse();
                                      },
                                      initialDelay: d.field0,
                                    );
                                  }),
                              findSafeSpot: (_) => null,
                              transition: (_) => null,
                              land: (_) => null,
                              precLand: (_) => null,
                              end: (_) => null)
                        ]).whereNotNull().toList(),
                      ),
                    ));
              },
            );

            lastLock = !missionNodes.isUnlocked(snapshot);
            return result;
          }),
    );
  }

  ThemeData _ignoreDisabled(BuildContext context) {
    var theme = Theme.of(context);
    return theme.copyWith(
        disabledColor: theme.textTheme.titleMedium?.color ?? Colors.white);
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

  final HashMap<UuidValue, ExpansionTileController> _expansionControllers =
      HashMap();

  ExpansionTileController getOrPut(UuidValue id) {
    return _expansionControllers.putIfAbsent(
        id, () => ExpansionTileController());
  }

  void collapseAll() {
    _expansionControllers.forEach((_, v) {
      v.collapse();
    });
  }

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
    _expansionControllers.remove(_missionNodes[index].id);
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

  void replaceNode(int index, FlutterMissionNode newNode) {
    _missionNodes[index] = newNode;
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
