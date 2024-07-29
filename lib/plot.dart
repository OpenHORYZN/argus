import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AltitudePlot extends StatefulWidget {
  const AltitudePlot({super.key, required this.controller});

  final PlotController controller;

  @override
  State<AltitudePlot> createState() => _AltitudePlotState();
}

class _AltitudePlotState extends State<AltitudePlot> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) => LineChart(
          LineChartData(
            titlesData: const FlTitlesData(
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false))),
            lineBarsData: [
              LineChartBarData(
                  spots: widget.controller.values
                      .map((point) => FlSpot(
                          point.x.millisecondsSinceEpoch.toDouble(), point.y))
                      .toList(),
                  dotData: const FlDotData(
                    show: false,
                  ),
                  color: Colors.yellow)
            ],
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}

class AltPoint {
  DateTime x;
  double y;
  AltPoint(this.x, this.y);
}

class PlotController with ChangeNotifier {
  final List<AltPoint> _values = <AltPoint>[];
  List<AltPoint> get values => _values.toList();

  void push(AltPoint value) {
    if (_values.length == 1000) {
      _values.removeAt(0);
    }
    _values.add(value);
    notifyListeners();
  }
}
