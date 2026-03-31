import 'package:flutter/foundation.dart';

import '../models/hike_record.dart';

/// Abstract interface for [HikeRecord] persistence.
///
/// Implemented by [HikeService]. Accepted by [HikeRecordingController] and
/// [AnalyticsViewModel] as a constructor parameter so the recording pipeline
/// can be tested without a live Hive box.
///
/// The interface uses distinct method names ([getAllRecords], [saveRecord],
/// [deleteRecord], [findUnfinishedRecord]) so that the concrete
/// [HikeService] class can keep its existing static API unchanged alongside
/// the instance implementation.
abstract class HikeRepository {
  /// Returns all persisted [HikeRecord] objects.
  List<HikeRecord> getAllRecords();

  /// Persists or updates [record].
  Future<void> saveRecord(HikeRecord record);

  /// Deletes the record with [id].
  Future<void> deleteRecord(String id);

  /// Incremented after every [saveRecord] or [deleteRecord]; listeners use
  /// this to reload.
  ValueNotifier<int> get versionNotifier;

  /// Returns the first [HikeRecord] with [HikeRecord.endTime] == null, or
  /// null if none exists.
  HikeRecord? findUnfinishedRecord();
}
