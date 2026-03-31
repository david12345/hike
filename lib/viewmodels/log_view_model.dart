import 'package:flutter/foundation.dart';

import '../models/hike_record.dart';
import '../repositories/hike_repository.dart';
import '../services/hike_service.dart';
import '../services/user_preferences_service.dart';

/// ChangeNotifier ViewModel for [LogScreen].
///
/// Owns:
/// - The sorted [List<HikeRecord>] (by [HikeRecord.startTime]).
/// - Listens to [HikeService.version] and [UserPreferencesService] to
///   automatically refresh and re-sort when data or preferences change.
/// - Exposes [deleteHike] and [toggleSort] methods.
///
/// [LogScreen] becomes a pure [ListenableBuilder] view.
class LogViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Repository
  // ---------------------------------------------------------------------------

  final HikeRepository _repository;

  LogViewModel({HikeRepository? repository})
      : _repository = repository ?? HikeService.instance {
    _repository.versionNotifier.addListener(_onVersionChanged);
    UserPreferencesService.instance.addListener(_onPrefsChanged);
    _rebuild();
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  List<HikeRecord> _hikes = [];

  /// The sorted list of hike records.
  List<HikeRecord> get hikes => _hikes;

  /// True when sorted newest-first (descending by [HikeRecord.startTime]).
  bool get sortDescending =>
      UserPreferencesService.instance.logSortOrder == LogSortOrder.descending;

  // ---------------------------------------------------------------------------
  // Listeners
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _repository.versionNotifier.removeListener(_onVersionChanged);
    UserPreferencesService.instance.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onVersionChanged() => _rebuild();
  void _onPrefsChanged() => _rebuild();

  void _rebuild() {
    final all = _repository.getAllRecords();
    all.sort((a, b) => sortDescending
        ? b.startTime.compareTo(a.startTime)
        : a.startTime.compareTo(b.startTime));
    _hikes = all;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Deletes the hike with [id]. Triggers [_rebuild] via version listener.
  Future<void> deleteHike(String id) => _repository.deleteRecord(id);

  /// Toggles the log sort order. Triggers [_rebuild] via prefs listener.
  void toggleSort() => UserPreferencesService.instance.toggleLogSortOrder();
}
