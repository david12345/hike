import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models/hike_record.dart';
import '../services/analytics_service.dart';
import '../services/hike_service.dart';
import '../services/user_preferences_service.dart';

// ---------------------------------------------------------------------------
// Isolate helpers — must be top-level for compute()
// ---------------------------------------------------------------------------

/// Payload passed to the background isolate.
class AnalyticsInput {
  final List<HikeRecord> filtered;
  final List<HikeRecord> allHikes;

  const AnalyticsInput({required this.filtered, required this.allHikes});
}

/// Top-level entry point required by Flutter's [compute] function.
AnalyticsStats runAnalytics(AnalyticsInput input) {
  return AnalyticsService.compute(input.filtered, input.allHikes);
}

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

/// ChangeNotifier ViewModel that owns filter state, SharedPreferences I/O,
/// and [AnalyticsService.compute] calls for [AnalyticsScreen].
///
/// Instantiated once in [_HomePageState.initState] and disposed in
/// [_HomePageState.dispose]. Passed to [AnalyticsScreen] as a constructor
/// parameter so cached stats survive tab switches.
class AnalyticsViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Observable state
  // ---------------------------------------------------------------------------

  AnalyticsFilterPreset? _activePreset;
  DateTimeRange? _customRange;
  AnalyticsStats? _cachedStats;
  bool _isLoading = false;
  bool _prefsLoaded = false;
  String? _errorMessage;

  /// The currently active preset filter; null when a custom range is active.
  AnalyticsFilterPreset? get activePreset => _activePreset;

  /// The custom date range; non-null only when [activePreset] is null.
  DateTimeRange? get customRange => _customRange;

  /// The most recently completed analytics result.
  AnalyticsStats? get cachedStats => _cachedStats;

  /// True while the isolate computation is running.
  bool get isLoading => _isLoading;

  /// True after preferences have been loaded from [UserPreferencesService].
  bool get prefsLoaded => _prefsLoaded;

  /// Non-null when the most recent compute failed.
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Private fields
  // ---------------------------------------------------------------------------

  /// Monotonically increasing counter to discard superseded compute results.
  int _computeGeneration = 0;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Reads the persisted filter from [UserPreferencesService] (already loaded
  /// at startup) and triggers the first computation.
  ///
  /// Must be called once after construction (e.g. in [_HomePageState.initState]).
  void init() {
    final prefs = UserPreferencesService.instance;
    _activePreset = prefs.analyticsFilterPreset;
    _customRange = prefs.analyticsCustomRange;
    _prefsLoaded = true;

    HikeService.version.addListener(_onVersionChanged);

    _triggerRecompute();
  }

  @override
  void dispose() {
    HikeService.version.removeListener(_onVersionChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Filter mutations
  // ---------------------------------------------------------------------------

  /// Applies a named preset and triggers recomputation.
  void setPreset(AnalyticsFilterPreset preset) {
    _activePreset = preset;
    _customRange = null;
    UserPreferencesService.instance.setAnalyticsPreset(preset);
    notifyListeners();
    _triggerRecompute();
  }

  /// Applies a custom date range and triggers recomputation.
  void setCustomRange(DateTimeRange range) {
    _activePreset = null;
    _customRange = range;
    UserPreferencesService.instance.setAnalyticsCustomRange(range);
    notifyListeners();
    _triggerRecompute();
  }

  // ---------------------------------------------------------------------------
  // Filter helpers
  // ---------------------------------------------------------------------------

  /// The effective date range (null means all-time).
  DateTimeRange? get effectiveRange {
    if (_activePreset != null) {
      return _activePreset!.toRange(DateTime.now());
    }
    return _customRange;
  }

  /// Applies the current filter to [all] and returns the matching subset.
  List<HikeRecord> applyFilter(List<HikeRecord> all) {
    final range = effectiveRange;
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

  // ---------------------------------------------------------------------------
  // Computation
  // ---------------------------------------------------------------------------

  void _onVersionChanged() => _triggerRecompute();

  /// Clears the current error state and retries the computation.
  void refresh() {
    _errorMessage = null;
    notifyListeners();
    _triggerRecompute();
  }

  /// Launches a background isolate computation, discarding any in-flight result
  /// that was superseded by a newer filter or hike-list change.
  void _triggerRecompute() {
    if (!_prefsLoaded) return;
    final gen = ++_computeGeneration;
    final allHikes = HikeService.getAll();
    final filtered = applyFilter(allHikes);

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Detach records from their Hive box before sending to the isolate.
    // HikeRecord extends HiveObject which holds an internal box reference that
    // cannot be sent across isolate message channels. Constructing fresh copies
    // with only the primitive fields used by AnalyticsService is safe.
    final detachedFiltered = filtered.map(_detach).toList();
    final detachedAll = allHikes.map(_detach).toList();

    compute(
      runAnalytics,
      AnalyticsInput(filtered: detachedFiltered, allHikes: detachedAll),
    ).then((stats) {
      if (gen != _computeGeneration) return; // superseded
      _cachedStats = stats;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }).catchError((Object e) {
      if (gen != _computeGeneration) return;
      debugPrint('[AnalyticsViewModel] isolate error: $e');
      _isLoading = false;
      _errorMessage = 'Could not compute stats';
      notifyListeners();
    });
  }

  /// Returns a plain detached copy of [r] with no Hive box reference.
  static HikeRecord _detach(HikeRecord r) => HikeRecord(
        id: r.id,
        name: r.name,
        startTime: r.startTime,
        endTime: r.endTime,
        distanceMeters: r.distanceMeters,
        latitudes: List<double>.from(r.latitudes),
        longitudes: List<double>.from(r.longitudes),
        steps: r.steps,
        calories: r.calories,
      );
}
