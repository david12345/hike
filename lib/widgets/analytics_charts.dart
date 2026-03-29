import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// Charts — shared helpers
// ---------------------------------------------------------------------------

const _kBarColor = kBrandGreen;

Widget _noDataPlaceholder(String message) {
  return SizedBox(
    height: 120,
    child: Center(
      child: Text(message,
          style: const TextStyle(color: Colors.grey, fontSize: 14)),
    ),
  );
}

double _niceInterval(double maxValue) {
  if (maxValue <= 0) return 1;
  final raw = maxValue / 5;
  final magnitude = (raw == 0) ? 1 : (raw.abs().toString().length - 1);
  final step = (raw / _pow10(magnitude)).ceil() * _pow10(magnitude);
  return step < 1 ? 1 : step.toDouble();
}

double _pow10(int exp) {
  double result = 1;
  for (int i = 0; i < exp; i++) {
    result *= 10;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Distance by Month bar chart
// ---------------------------------------------------------------------------

class MonthlyDistanceChart extends StatelessWidget {
  final List<MonthlyBucket> data;

  const MonthlyDistanceChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    if (data.isEmpty) return _noDataPlaceholder(l10n.statsNoData);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: data[i].distanceKm,
            color: _kBarColor,
            width: 16,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      ));
    }

    final maxY = data.map((b) => b.distanceKm).reduce((a, b) => a > b ? a : b);
    final yInterval = _niceInterval(maxY);

    final chart = SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: (maxY * 1.15).ceilToDouble(),
          gridData: FlGridData(
            show: true,
            horizontalInterval: yInterval,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0x22000000), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  NumberFormat.compact(locale: locale).format(v),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final stride = (data.length / 12).ceil();
                  if (idx % stride != 0) return const SizedBox.shrink();
                  final bucket = data[idx];
                  final shortLabel = DateFormat('MMM', locale)
                      .format(DateTime(bucket.year, bucket.month));
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      shortLabel,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: groups,
        ),
      ),
    );

    if (data.length <= 12) {
      return Card(
        elevation: 0,
        child: Padding(padding: const EdgeInsets.all(12), child: chart),
      );
    }

    const barWidth = 30.0;
    final chartWidth = data.length * barWidth + 60;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: chartWidth, child: chart),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day-of-week bar chart (horizontal)
// ---------------------------------------------------------------------------

class DayOfWeekChart extends StatelessWidget {
  final List<int> counts;

  const DayOfWeekChart({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    // Build locale-aware day-of-week abbreviations starting from Monday.
    // DateTime(2024, 1, 1) is a Monday.
    final dayFmt = DateFormat('E', locale);
    final labels = List.generate(
        7, (i) => dayFmt.format(DateTime(2024, 1, 1 + i)));

    final maxY = counts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) return _noDataPlaceholder(l10n.statsNoData);
    final xInterval = _niceInterval(maxY < 1 ? 1 : maxY);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < 7; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: counts[i].toDouble(),
            color: _kBarColor,
            width: 14,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(3)),
          ),
        ],
      ));
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: (maxY * 1.15 + 1).ceilToDouble(),
              barTouchData: BarTouchData(enabled: false),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: false,
                drawVerticalLine: true,
                verticalInterval: xInterval,
                getDrawingVerticalLine: (_) =>
                    const FlLine(color: Color(0x22000000), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(labels[idx],
                              style: const TextStyle(fontSize: 10)),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: xInterval,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
              barGroups: groups,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Distance distribution bar chart
// ---------------------------------------------------------------------------

class DistributionChart extends StatelessWidget {
  final List<int> buckets;

  const DistributionChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const bucketLabels = ['0–2', '2–5', '5–10', '10–20', '20+'];
    final maxY = buckets.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) return _noDataPlaceholder(l10n.statsNoData);
    final yInterval = _niceInterval(maxY < 1 ? 1 : maxY);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < 5; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: buckets[i].toDouble(),
            color: _kBarColor,
            width: 28,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      ));
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).statsDistributionAxisLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: (maxY * 1.15 + 1).ceilToDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: yInterval,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0x22000000), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: yInterval,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= 5) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              bucketLabels[idx],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: groups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
