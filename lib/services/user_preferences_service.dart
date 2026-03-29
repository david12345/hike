import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Sort order enums
// ---------------------------------------------------------------------------

/// Sort order for the hike log list.
enum LogSortOrder { descending, ascending }

/// Sort order for the trails list.
enum TrailsSortOrder { ascending, descending }

// ---------------------------------------------------------------------------
// Analytics filter preset enum
// ---------------------------------------------------------------------------

/// The active filter preset on the Analytics screen.
enum AnalyticsFilterPreset { days7, days30, months3, all }

extension AnalyticsFilterPresetExt on AnalyticsFilterPreset {
  String get prefsKey {
    switch (this) {
      case AnalyticsFilterPreset.days7:
        return '7d';
      case AnalyticsFilterPreset.days30:
        return '30d';
      case AnalyticsFilterPreset.months3:
        return '3mo';
      case AnalyticsFilterPreset.all:
        return 'all';
    }
  }

  static AnalyticsFilterPreset? fromKey(String? key) {
    for (final p in AnalyticsFilterPreset.values) {
      if (p.prefsKey == key) return p;
    }
    return null;
  }

  String get label {
    switch (this) {
      case AnalyticsFilterPreset.days7:
        return '7 d';
      case AnalyticsFilterPreset.days30:
        return '30 d';
      case AnalyticsFilterPreset.months3:
        return '3 mo';
      case AnalyticsFilterPreset.all:
        return 'All';
    }
  }

  /// Returns the [DateTimeRange] for this preset relative to [now].
  /// Returns null for [AnalyticsFilterPreset.all].
  DateTimeRange? toRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (this) {
      case AnalyticsFilterPreset.days7:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case AnalyticsFilterPreset.days30:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case AnalyticsFilterPreset.months3:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 89)),
          end: today,
        );
      case AnalyticsFilterPreset.all:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Singleton service that centralises all [SharedPreferences] access.
///
/// Initialised once in [SplashScreen] via [init]. All reads are synchronous
/// after that. Extends [ChangeNotifier] so widgets can rebuild on preference
/// changes via [ListenableBuilder].
///
/// Pattern reference: [TilePreferenceService].
class UserPreferencesService extends ChangeNotifier {
  UserPreferencesService._();

  /// The single shared instance.
  static final UserPreferencesService instance = UserPreferencesService._();

  // ---------------------------------------------------------------------------
  // Private preference keys
  // ---------------------------------------------------------------------------

  static const _kLogSortDescending = 'log_sort_descending';
  static const _kTrailsSortAscending = 'trails_sort_ascending';
  static const _kAnalyticsPreset = 'analytics_preset';
  static const _kAnalyticsStartMs = 'analytics_start_ms';
  static const _kAnalyticsEndMs = 'analytics_end_ms';

  // ---------------------------------------------------------------------------
  // In-memory state
  // ---------------------------------------------------------------------------

  late SharedPreferences _prefs;

  LogSortOrder _logSortOrder = LogSortOrder.descending;
  TrailsSortOrder _trailsSortOrder = TrailsSortOrder.ascending;
  AnalyticsFilterPreset? _analyticsFilterPreset = AnalyticsFilterPreset.days30;
  DateTimeRange? _analyticsCustomRange;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  /// Loads all preferences from disk. Must be awaited before the app navigates
  /// to [HomePage]. Called from [SplashScreen._initAndNavigate].
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _logSortOrder = (_prefs.getBool(_kLogSortDescending) ?? true)
        ? LogSortOrder.descending
        : LogSortOrder.ascending;

    _trailsSortOrder = (_prefs.getBool(_kTrailsSortAscending) ?? true)
        ? TrailsSortOrder.ascending
        : TrailsSortOrder.descending;

    final presetKey = _prefs.getString(_kAnalyticsPreset);
    final startMs = _prefs.getInt(_kAnalyticsStartMs);
    final endMs = _prefs.getInt(_kAnalyticsEndMs);

    final preset = AnalyticsFilterPresetExt.fromKey(presetKey);
    if (preset != null) {
      _analyticsFilterPreset = preset;
      _analyticsCustomRange = null;
    } else if (startMs != null && endMs != null) {
      _analyticsFilterPreset = null;
      _analyticsCustomRange = DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(startMs),
        end: DateTime.fromMillisecondsSinceEpoch(endMs),
      );
    } else {
      _analyticsFilterPreset = AnalyticsFilterPreset.days30;
      _analyticsCustomRange = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Log sort order
  // ---------------------------------------------------------------------------

  /// The current log list sort order.
  LogSortOrder get logSortOrder => _logSortOrder;

  /// Toggles the log sort order and persists it (fire-and-forget).
  void toggleLogSortOrder() {
    _logSortOrder = _logSortOrder == LogSortOrder.descending
        ? LogSortOrder.ascending
        : LogSortOrder.descending;
    _prefs
        .setBool(_kLogSortDescending, _logSortOrder == LogSortOrder.descending)
        .ignore();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Trails sort order
  // ---------------------------------------------------------------------------

  /// The current trails list sort order.
  TrailsSortOrder get trailsSortOrder => _trailsSortOrder;

  /// Toggles the trails sort order and persists it (fire-and-forget).
  void toggleTrailsSortOrder() {
    _trailsSortOrder = _trailsSortOrder == TrailsSortOrder.ascending
        ? TrailsSortOrder.descending
        : TrailsSortOrder.ascending;
    _prefs
        .setBool(
            _kTrailsSortAscending, _trailsSortOrder == TrailsSortOrder.ascending)
        .ignore();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Analytics filter
  // ---------------------------------------------------------------------------

  /// The active analytics filter preset, or null when a custom range is active.
  AnalyticsFilterPreset? get analyticsFilterPreset => _analyticsFilterPreset;

  /// The custom date range, non-null only when [analyticsFilterPreset] is null.
  DateTimeRange? get analyticsCustomRange => _analyticsCustomRange;

  /// Sets a preset filter and persists it. Clears custom range.
  void setAnalyticsPreset(AnalyticsFilterPreset preset) {
    _analyticsFilterPreset = preset;
    _analyticsCustomRange = null;
    _prefs.setString(_kAnalyticsPreset, preset.prefsKey).ignore();
    _prefs.remove(_kAnalyticsStartMs).ignore();
    _prefs.remove(_kAnalyticsEndMs).ignore();
    notifyListeners();
  }

  /// Sets a custom date range and persists it. Clears preset.
  void setAnalyticsCustomRange(DateTimeRange range) {
    _analyticsFilterPreset = null;
    _analyticsCustomRange = range;
    _prefs.remove(_kAnalyticsPreset).ignore();
    _prefs
        .setInt(_kAnalyticsStartMs, range.start.millisecondsSinceEpoch)
        .ignore();
    _prefs
        .setInt(_kAnalyticsEndMs, range.end.millisecondsSinceEpoch)
        .ignore();
    notifyListeners();
  }
}
