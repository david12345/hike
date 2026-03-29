import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/hike_record.dart';
import '../services/analytics_service.dart';
import '../services/user_preferences_service.dart';
import '../viewmodels/analytics_view_model.dart';
import 'about_screen.dart';
import '../widgets/analytics_charts.dart';

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class AnalyticsScreen extends StatelessWidget {
  final AnalyticsViewModel viewModel;

  const AnalyticsScreen({super.key, required this.viewModel});

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
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final isLoading = viewModel.isLoading;
        final stats = viewModel.cachedStats ?? AnalyticsStats.empty;

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).statsAppBarTitle),
            centerTitle: true,
            actions: [
              if (isLoading)
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
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'about',
                      child: Text(
                          AppLocalizations.of(context).statsAboutMenuItem)),
                ],
              ),
            ],
          ),
          body: !viewModel.prefsLoaded
              ? const Center(child: CircularProgressIndicator())
              : viewModel.cachedStats == null && isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewModel.errorMessage != null && viewModel.cachedStats == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(height: 16),
                                Text(
                                  viewModel.errorMessage!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: viewModel.refresh,
                                  child: Text(
                                      AppLocalizations.of(context).statsRetry),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DateRangeFilterCard(
                            activePreset: viewModel.activePreset,
                            customRange: viewModel.customRange,
                            onPreset: viewModel.setPreset,
                            onCustomRange: viewModel.setCustomRange,
                          ),
                          const SizedBox(height: 16),
                          if (viewModel.filteredIsEmpty)
                            _EmptyState(hasAnyHikes: viewModel.hasAnyHikes)
                          else ...[
                            _SectionHeader(AppLocalizations.of(context)
                                .statsSectionSummary),
                            const SizedBox(height: 8),
                            _MetricsGrid(stats: stats),
                            const SizedBox(height: 16),
                            _SectionHeader(AppLocalizations.of(context)
                                .statsSectionPersonalBests),
                            const SizedBox(height: 8),
                            _PersonalBestsGrid(stats: stats),
                            const SizedBox(height: 16),
                            _SectionHeader(AppLocalizations.of(context)
                                .statsSectionStreaks),
                            const SizedBox(height: 8),
                            _StreaksRow(stats: stats),
                            const SizedBox(height: 16),
                            _SectionHeader(AppLocalizations.of(context)
                                .statsSectionDistanceByMonth),
                            const SizedBox(height: 8),
                            MonthlyDistanceChart(data: stats.monthlyDistance),
                            const SizedBox(height: 16),
                            _SectionHeader(AppLocalizations.of(context)
                                .statsSectionActivityByDay),
                            const SizedBox(height: 8),
                            DayOfWeekChart(counts: stats.dayOfWeekCounts),
                            const SizedBox(height: 16),
                            _SectionHeader(AppLocalizations.of(context)
                                .statsSectionDistributionTitle),
                            const SizedBox(height: 8),
                            DistributionChart(buckets: stats.distanceBuckets),
                          ],
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Date range filter card
// ---------------------------------------------------------------------------

class _DateRangeFilterCard extends StatelessWidget {
  final AnalyticsFilterPreset? activePreset;
  final DateTimeRange? customRange;
  final ValueChanged<AnalyticsFilterPreset> onPreset;
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
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat('MMM d, y', locale);
    final now = DateTime.now();
    final effectiveRange = activePreset?.toRange(now) ?? customRange;

    final startLabel = effectiveRange != null
        ? dateFmt.format(effectiveRange.start)
        : l10n.statsDateStart;
    final endLabel = effectiveRange != null
        ? dateFmt.format(effectiveRange.end)
        : l10n.statsDateToday;

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
              children: AnalyticsFilterPreset.values.map((p) {
                final selected = activePreset == p;
                return ChoiceChip(
                  label: Text(p.localizedLabel(l10n)),
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
    final l10n = AppLocalizations.of(context);
    final msg = hasAnyHikes ? l10n.statsEmptyPeriod : l10n.statsEmptyNoHikes;
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
    final l10n = AppLocalizations.of(context);
    final hasSteps = stats.totalSteps > 0;

    final tiles = <Widget>[
      _MetricTile(
          label: l10n.statsMetricTotalHikes,
          value: NumberFormat('#,##0', 'en').format(stats.totalHikes)),
      _MetricTile(
          label: l10n.statsMetricTotalDistance,
          value: _fmtKm(stats.totalDistanceKm)),
      _MetricTile(
          label: l10n.statsMetricTotalTime,
          value: _fmtDuration(stats.totalDuration)),
      _MetricTile(
          label: l10n.statsMetricAvgDistance,
          value: _fmtKm(stats.avgDistanceKm)),
      _MetricTile(
          label: l10n.statsMetricAvgDuration,
          value: _fmtDuration(stats.avgDuration)),
      _MetricTile(
          label: l10n.statsMetricAvgPace,
          value: _fmtPace(stats.avgPaceMinPerKm)),
      _MetricTile(
          label: l10n.statsMetricLongestDistance,
          value: _fmtKm(
              (stats.longestByDistance?.distanceMeters ?? 0) / 1000.0),
          subtitle: stats.longestByDistance?.name),
      _MetricTile(
          label: l10n.statsMetricLongestDuration,
          value: _fmtDuration(
              stats.longestByDuration?.duration ?? Duration.zero),
          subtitle: stats.longestByDuration?.name),
      if (hasSteps)
        _MetricTile(
            label: l10n.statsMetricTotalSteps,
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
    final l10n = AppLocalizations.of(context);
    final hasBestPace = stats.bestPace != null;
    final hasMostSteps = stats.mostSteps != null;

    final tiles = <Widget>[
      _MetricTile(
          label: l10n.statsMetricBestDistance,
          value: _fmtKm(
              (stats.longestByDistance?.distanceMeters ?? 0) / 1000.0),
          subtitle: stats.longestByDistance?.name),
      if (hasBestPace)
        _MetricTile(
            label: l10n.statsMetricBestPace,
            value: _fmtPace(_paceForHike(stats.bestPace!)),
            subtitle: stats.bestPace!.name),
      _MetricTile(
          label: l10n.statsMetricMostActiveWeek,
          value: l10n.statsMetricMostActiveWeekValue(
              stats.mostHikesInOneWeek)),
      if (hasMostSteps)
        _MetricTile(
            label: l10n.statsMetricMostSteps,
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
    final l10n = AppLocalizations.of(context);
    final cStr = l10n.statsStreakDays(stats.currentStreak);
    final lStr = l10n.statsStreakDays(stats.longestStreak);
    return Row(
      children: [
        Expanded(
          child: _MetricTile(label: l10n.statsMetricCurrentStreak, value: cStr),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(label: l10n.statsMetricLongestStreak, value: lStr),
        ),
      ],
    );
  }
}

