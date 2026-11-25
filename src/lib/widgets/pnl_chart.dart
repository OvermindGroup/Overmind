import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/money.dart';
import '../domain/trades.dart';

/// Cumulative P&L across a trade window.
///
/// Takes the domain curve instead of a parallel spot list and tooltip list, so
/// the two can never drift apart.
class PnLChart extends StatelessWidget {
  const PnLChart(this.points, {super.key});

  final List<PnlPoint> points;

  static final DateFormat _tooltipFormat = DateFormat('MMM dd, yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  formatCurrency(value),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final point in points)
                FlSpot(point.index.toDouble(), point.cumulative),
            ],
            isCurved: true,
            color: Colors.blue,
            dotData: const FlDotData(show: true),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => [
              for (final spot in touchedSpots)
                if (spot.spotIndex < points.length)
                  LineTooltipItem(
                    '${_tooltipFormat.format(points[spot.spotIndex].time)}\n'
                    'Cumulative: ${formatCurrency(points[spot.spotIndex].cumulative)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
