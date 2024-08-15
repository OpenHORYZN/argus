import 'package:argus/title_bar/gradient_container.dart';
import 'package:flutter/material.dart';

class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleBar({
    super.key,
    required Stream<bool>? onlineStream,
    required Stream<int>? stepStream,
    required String machine,
  })  : _onlineStream = onlineStream,
        _stepStream = stepStream,
        _machine = machine;

  final Stream<bool>? _onlineStream;
  final Stream<int>? _stepStream;
  final String _machine;

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
      actions: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Center(
            child: Text(
              "Node: $_machine",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
      centerTitle: true,
      notificationPredicate: (notification) => false,
      title: const Text('Argus Flight Management'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
