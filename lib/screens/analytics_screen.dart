import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hike_record.dart';
import '../services/analytics_service.dart';
import '../services/hike_service.dart';
import 'about_screen.dart';

// ---------------------------------------------------------------------------
// SharedPreferences keys
// ---------------------------------------------------------------------------
const _kPrefStartMs = 'analytics_start_ms';
const _kPrefEndMs = 'analytics_end_ms';
const _kPrefPreset = 'analytics_preset';

// ---------------------------------------------------------------------------
// Preset definitions
// ---------------------------------------------------------------------------
enum _Preset { days7, days30, months3, all }

extension _PresetExt on _Preset {
  String get label {
    switch (this) {
      case _Preset.days7:
        return '7 d';
      case _Preset.days30:
        return '30 d';
      case _Preset.months3:
        return '3 mo';
      case _Preset.all:
        return 'All';
    }
  }

  String get prefsKey {
    switch (this) {
      case _Preset.days7:
        return '7d';
      case _Preset.days30:
        return '30d';
      case _Preset.months3:
        return '3mo';
      case _Preset.all:
        return 'all';
    }
  }

  static _Preset? fromKey(String? key) {
    for (final p in _Preset.values) {
      if (p.prefsKey == key) return p;
    }
    return null;
  }

  /// Returns the [DateTimeRange] for this preset relative to [now].
  /// Returns null for [_Preset.all].
  DateTimeRange? toRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (this) {
      case _Preset.days7:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _Preset.days30:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case _Preset.months3:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 89)),
          end: today,
        );
      case _Preset.all:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Isolate helpers (must be top-level for compute())
// ---------------------------------------------------------------------------

/// Payload passed to the background isolate.
class _AnalyticsInput {
  final List<HikeRecord> filtered;
  final List<HikeRecord> allHikes;

  const _AnalyticsInput({required this.filtered, required this.allHikes});
}

/// Top-level entry point required by Flutter's [compute] function.
AnalyticsStats _runAnalytics(_AnalyticsInput input) {
  return AnalyticsService.compute(input.filtered, input.allHikes);
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Preset? _activePreset = _Preset.days30;
  DateTimeRange? _customRange;
  bool _prefsLoaded = false;

  /// Monotonically increasing counter used to discard results from superseded
  /// computations triggered while a previous isolate is still running.
  int _computeGeneration = 0;

  /// Most recently completed analytics result. Displayed while a new
  /// computation is in progress to prevent the screen from going blank.
  AnalyticsStats? _cachedStats;

  /// The in-flight compute Future. Rebuilt whenever [HikeService.version] or
  /// the active filter changes.
  Future<AnalyticsStats>? _statsFuture;

  @override
  void initState() {
    super.initState();
    HikeService.version.addListener(_onVersionChanged);
    _loadPrefs();
  }

  @override
  void dispose() {
    HikeService.version.removeListener(_onVersionChanged);
    super.dispose();
  }

  void _onVersionChanged() {
    _triggerRecompute();
  }

  /// Launches a background isolate computation, cancelling any in-flight result.
  void _triggerRecompute() {
    if (!_prefsLoaded) return;
    final gen = ++_computeGeneration;
    final allHikes = HikeService.getAll();
    final filtered = _applyFilter(allHikes);
    final future = compute(
      _runAnalytics,
      _AnalyticsInput(filtered: filtered, allHikes: allHikes),
    );
    setState(() {
      _statsFuture = future;
    });
    future.then((stats) {
      if (!mounted) return;
      if (gen != _computeGeneration) return; // superseded
      setState(() {
        _cachedStats = stats;
        _statsFuture = null;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      if (gen != _computeGeneration) return;
      debugPrint('[Analytics] isolate error: $e');
      // Keep previous cached result; clear future so UI does not stay in
      // loading state indefinitely.
      setState(() {
        _statsFuture = null;
      });
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final presetKey = prefs.getString(_kPrefPreset);
    final startMs = prefs.getInt(_kPrefStartMs);
    final endMs = prefs.getInt(_kPrefEndMs);

    final preset = _PresetExt.fromKey(presetKey);
    DateTimeRange? custom;
    if (preset == null && startMs != null && endMs != null) {
      custom = DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(startMs),
        end: DateTime.fromMillisecondsSinceEpoch(endMs),
      );
    }

    if (mounted) {
      setState(() {
        _activePreset = preset ?? (custom != null ? null : _Preset.days30);
        _customRange = custom;
        _prefsLoaded = true;
      });
      _triggerRecompute();
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activePreset != null) {
      await prefs.setString(_kPrefPreset, _activePreset!.prefsKey);
      await prefs.remove(_kPrefStartMs);
      await prefs.remove(_kPrefEndMs);
    } else if (_customRange != null) {
      await prefs.remove(_kPrefPreset);
      await prefs.setInt(
          _kPrefStartMs, _customRange!.start.millisecondsSinceEpoch);
      await prefs.setInt(
          _kPrefEndMs, _customRange!.end.millisecondsSinceEpoch);
    }
  }

  void _applyPreset(_Preset preset) {
    setState(() {
      _activePreset = preset;
      _customRange = null;
    });
    _savePrefs();
    _triggerRecompute();
  }

  void _applyCustomRange(DateTimeRange range) {
    setState(() {
      _activePreset = null;
      _customRange = range;
    });
    _savePrefs();
    _triggerRecompute();
  }

  /// Returns the effective date range (null means "all time").
  DateTimeRange? get _effectiveRange {
    if (_activePreset != null) {
      return _activePreset!.toRange(DateTime.now());
    }
    return _customRange;
  }

  List<HikeRecord> _applyFilter(List<HikeRecord> all) {
    final range = _effectiveRange;
    if (range == null) return all;
    final start =
        DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
        range.end.year, range.end.month, range.end.day, 23, 59, 59);
    return all
        .where((h) =>
            !h.startTime.isBefore(start) && !h.startTime.isAfter(end))
        .toList();
  }

  void _openAbout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AboutScreen(onTap: () => Navigator.pop(context)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether a background computation is currently running.
    final bool isComputing = _statsFuture != null;
    // Use the most recently completed result, or empty while loading the first.
    final stats = _cachedStats ?? AnalyticsStats.empty;
    // Snapshot the filter state for the empty-state check below.
    final allHikes = HikeService.getAll();
    final filtered = _applyFilter(allHikes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        centerTitle: true,
        actions: [
          // Show a small loading indicator in the AppBar while computing.
          if (isComputing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') _openAbout(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'about', child: Text('About')),
            ],
          ),
        ],
      ),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : _cachedStats == null && isComputing
              // First-load: no cached result yet — show a spinner.
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateRangeFilterCard(
                        activePreset: _activePreset,
                        customRange: _customRange,
                        onPreset: _applyPreset,
                        onCustomRange: _applyCustomRange,
                      ),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        _EmptyState(hasAnyHikes: allHikes.isNotEmpty)
                      else ...[
                        const _SectionHeader('Summary'),
                        const SizedBox(height: 8),
                        _MetricsGrid(stats: stats),
                        const SizedBox(height: 16),
                        const _SectionHeader('Personal Bests'),
                        const SizedBox(height: 8),
                        _PersonalBestsGrid(stats: stats),
                        const SizedBox(height: 16),
                        const _SectionHeader('Streaks'),
                        const SizedBox(height: 8),
                        _StreaksRow(stats: stats),
                        const SizedBox(height: 16),
                        const _SectionHeader('Distance by Month'),
                        const SizedBox(height: 8),
                        _MonthlyDistanceChart(data: stats.monthlyDistance),
                        const SizedBox(height: 16),
                        const _SectionHeader('Activity by Day of Week'),
                        const SizedBox(height: 8),
                        _DayOfWeekChart(counts: stats.dayOfWeekCounts),
                        const SizedBox(height: 16),
                        const _SectionHeader('Distance Distribution'),
                        const SizedBox(height: 8),
                        _DistributionChart(buckets: stats.distanceBuckets),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date range filter card
// ---------------------------------------------------------------------------

class _DateRangeFilterCard extends StatelessWidget {
  final _Preset? activePreset;
  final DateTimeRange? customRange;
  final ValueChanged<_Preset> onPreset;
  final ValueChanged<DateTimeRange> onCustomRange;

  const _DateRangeFilterCard({
    required this.activePreset,
    required this.customRange,
    required this.onPreset,
    required this.onCustomRange,
  });

  Future<void> _pickStart(BuildContext context) async {
    final now = DateTime.now();
    final initial = customRange?.start ??
        activePreset?.toRange(now)?.start ??
        now.subtract(const Duration(days: 29));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    final end = customRange?.end ?? activePreset?.toRange(now)?.end ?? now;
    final clampedEnd = end.isBefore(picked) ? picked : end;
    onCustomRange(DateTimeRange(start: picked, end: clampedEnd));
  }

  Future<void> _pickEnd(BuildContext context) async {
    final now = DateTime.now();
    final initial =
        customRange?.end ?? activePreset?.toRange(now)?.end ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    final start = customRange?.start ??
        activePreset?.toRange(now)?.start ??
        now.subtract(const Duration(days: 29));
    final clampedStart = start.isAfter(picked) ? picked : start;
    onCustomRange(DateTimeRange(start: clampedStart, end: picked));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('MMM d, y');
    final now = DateTime.now();
    final effectiveRange = activePreset?.toRange(now) ?? customRange;

    final startLabel =
        effectiveRange != null ? dateFmt.format(effectiveRange.start) : 'Start';
    final endLabel =
        effectiveRange != null ? dateFmt.format(effectiveRange.end) : 'Today';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _DateChip(
                    icon: Icons.calendar_today_outlined,
                    label: startLabel,
                    onTap: () => _pickStart(context),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–'),
                ),
                Expanded(
                  child: _DateChip(
                    icon: Icons.calendar_today_outlined,
                    label: endLabel,
                    onTap: () => _pickEnd(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _Preset.values.map((p) {
                final selected = activePreset == p;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: selected,
                  selectedColor: cs.primaryContainer,
                  onSelected: (_) => onPreset(p),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 16),
        ),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final bool hasAnyHikes;

  const _EmptyState({required this.hasAnyHikes});

  @override
  Widget build(BuildContext context) {
    final msg = hasAnyHikes ? 'No hikes in this period' : 'No hikes recorded yet';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(msg,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: cs.primary,
            ),
          ),
          Divider(height: 4, color: cs.primary.withAlpha(80)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric tile
// ---------------------------------------------------------------------------

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;

  const _MetricTile({
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metrics grid
// ---------------------------------------------------------------------------

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _fmtPace(double minPerKm) {
  if (minPerKm <= 0 || minPerKm.isInfinite || minPerKm.isNaN) return '--';
  final totalSeconds = (minPerKm * 60).round();
  final mm = totalSeconds ~/ 60;
  final ss = totalSeconds.remainder(60);
  return '$mm:${ss.toString().padLeft(2, '0')} min/km';
}

String _fmtKm(double km) => '${NumberFormat('0.00', 'en').format(km)} km';

class _MetricsGrid extends StatelessWidget {
  final AnalyticsStats stats;

  const _MetricsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasSteps = stats.totalSteps > 0;

    final tiles = <Widget>[
      _MetricTile(
          label: 'Total Hikes',
          value: NumberFormat('#,##0', 'en').format(stats.totalHikes)),
      _MetricTile(
          label: 'Total Distance', value: _fmtKm(stats.totalDistanceKm)),
      _MetricTile(
          label: 'Total Time', value: _fmtDuration(stats.totalDuration)),
      _MetricTile(
          label: 'Avg Distance', value: _fmtKm(stats.avgDistanceKm)),
      _MetricTile(
          label: 'Avg Duration', value: _fmtDuration(stats.avgDuration)),
      _MetricTile(
          label: 'Avg Pace', value: _fmtPace(stats.avgPaceMinPerKm)),
      _MetricTile(
          label: 'Longest (distance)',
          value: _fmtKm(
              (stats.longestByDistance?.distanceMeters ?? 0) / 1000.0),
          subtitle: stats.longestByDistance?.name),
      _MetricTile(
          label: 'Longest (duration)',
          value: _fmtDuration(
              stats.longestByDuration?.duration ?? Duration.zero),
          subtitle: stats.longestByDuration?.name),
      if (hasSteps)
        _MetricTile(
            label: 'Total Steps',
            value: NumberFormat('#,##0', 'en').format(stats.totalSteps)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: tiles,
    );
  }
}

// ---------------------------------------------------------------------------
// Personal bests grid
// ---------------------------------------------------------------------------

class _PersonalBestsGrid extends StatelessWidget {
  final AnalyticsStats stats;

  const _PersonalBestsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasBestPace = stats.bestPace != null;
    final hasMostSteps = stats.mostSteps != null;

    final tiles = <Widget>[
      _MetricTile(
          label: 'Best Distance',
          value: _fmtKm(
              (stats.longestByDistance?.distanceMeters ?? 0) / 1000.0),
          subtitle: stats.longestByDistance?.name),
      if (hasBestPace)
        _MetricTile(
            label: 'Best Pace',
            value: _fmtPace(_paceForHike(stats.bestPace!)),
            subtitle: stats.bestPace!.name),
      _MetricTile(
          label: 'Most Active Week',
          value: '${stats.mostHikesInOneWeek} hikes'),
      if (hasMostSteps)
        _MetricTile(
            label: 'Most Steps',
            value: NumberFormat('#,##0', 'en').format(stats.mostSteps!.steps),
            subtitle: stats.mostSteps!.name),
    ];

    if (tiles.isEmpty) {
      return const _MetricTile(label: 'No data', value: '--');
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: tiles,
    );
  }

  static double _paceForHike(HikeRecord h) {
    final km = h.distanceMeters / 1000.0;
    if (km <= 0) return 0;
    final minutes = h.duration.inSeconds / 60.0;
    return minutes / km;
  }
}

// ---------------------------------------------------------------------------
// Streaks row
// ---------------------------------------------------------------------------

class _StreaksRow extends StatelessWidget {
  final AnalyticsStats stats;

  const _StreaksRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cStr =
        stats.currentStreak == 1 ? '1 day' : '${stats.currentStreak} days';
    final lStr =
        stats.longestStreak == 1 ? '1 day' : '${stats.longestStreak} days';
    return Row(
      children: [
        Expanded(
          child: _MetricTile(label: 'Current Streak', value: cStr),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(label: 'Longest Streak', value: lStr),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Charts — shared helpers
// ---------------------------------------------------------------------------

const _kBarColor = Color(0xFF2E7D32);

Widget _noDataPlaceholder(String message) {
  return SizedBox(
    height: 120,
    child: Center(
      child: Text(message,
          style: const TextStyle(color: Colors.grey, fontSize: 14)),
    ),
  );
}

/// Returns a "nice" round interval for chart axes.
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

class _MonthlyDistanceChart extends StatelessWidget {
  final List<MonthlyBucket> data;

  const _MonthlyDistanceChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _noDataPlaceholder('No data for this period');

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
                  NumberFormat.compact(locale: 'en').format(v),
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
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      data[idx].shortLabel,
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

    // Horizontally scrollable for > 12 months.
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

class _DayOfWeekChart extends StatelessWidget {
  final List<int> counts; // 7 elements, index 0=Mon

  const _DayOfWeekChart({required this.counts});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final maxY = counts.reduce((a, b) => a > b ? a : b).toDouble();
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

class _DistributionChart extends StatelessWidget {
  final List<int> buckets; // 5 elements

  const _DistributionChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    const bucketLabels = ['0–2', '2–5', '5–10', '10–20', '20+'];
    final maxY = buckets.reduce((a, b) => a > b ? a : b).toDouble();
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
            const Text('km per hike',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
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
