import 'package:flutter/material.dart';

class GradientContainer extends StatefulWidget {
  final VehicleState state;
  const GradientContainer({super.key, required this.state});

  @override
  GradientContainerState createState() => GradientContainerState();
}

class GradientContainerState extends State<GradientContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color;

    if (widget.state == VehicleState.offline) {
      color = const Color.fromARGB(255, 255, 18, 2);
    } else if (widget.state == VehicleState.flying) {
      color = const Color.fromARGB(255, 0, 110, 255);
    } else {
      color = const Color.fromARGB(255, 5, 175, 14);
    }

    String text;
    if (widget.state == VehicleState.offline) {
      text = "Offline";
    } else if (widget.state == VehicleState.flying) {
      text = "Flying";
    } else if (widget.state == VehicleState.online) {
      text = "Online";
    } else {
      text = "Ready";
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: _controller.value + 3.3,
              focal: Alignment.topLeft,
              colors: [
                color,
                Colors.transparent,
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum VehicleState { online, ready, flying, offline }
