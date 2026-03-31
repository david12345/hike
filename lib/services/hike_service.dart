import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hike_record.dart';
import '../repositories/hike_repository.dart';

class HikeService implements HikeRepository {
  static const _boxName = 'hikes';

  // ---------------------------------------------------------------------------
  // Singleton instance (implements HikeRepository)
  // ---------------------------------------------------------------------------

  HikeService._();

  /// The single shared instance — use this when a [HikeRepository] is needed.
  static final HikeService instance = HikeService._();

  // ---------------------------------------------------------------------------
  // Shared state
  // ---------------------------------------------------------------------------

  /// Incremented after every [save] or [delete]. Screens and view-models listen
  /// to this to know when to reload from Hive.
  static final ValueNotifier<int> version = ValueNotifier(0);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  static Future<void> init() async {
    Hive.registerAdapter(HikeRecordAdapter());
    await Hive.openBox<HikeRecord>(_boxName);
  }

  // ---------------------------------------------------------------------------
  // Internal box accessor
  // ---------------------------------------------------------------------------

  static Box<HikeRecord> get _box => Hive.box<HikeRecord>(_boxName);

  // ---------------------------------------------------------------------------
  // Static API (preserved for existing call sites)
  // ---------------------------------------------------------------------------

  static List<HikeRecord> getAll() =>
      _box.values.toList(); // no reversal; callers sort explicitly

  static Future<void> save(HikeRecord record) async {
    await _box.put(record.id, record);
    version.value++;
  }

  static Future<void> delete(String id) async {
    await _box.delete(id);
    version.value++;
  }

  /// Returns the first [HikeRecord] with `endTime == null`, or `null` if
  /// none exists.
  ///
  /// A non-null result indicates an interrupted recording session that can
  /// be offered for recovery.
  static HikeRecord? findUnfinished() {
    for (final r in _box.values) {
      if (r.endTime == null) return r;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // HikeRepository interface (instance methods delegate to static helpers)
  // ---------------------------------------------------------------------------

  @override
  ValueNotifier<int> get versionNotifier => HikeService.version;

  @override
  List<HikeRecord> getAllRecords() => HikeService.getAll();

  @override
  Future<void> saveRecord(HikeRecord record) => HikeService.save(record);

  @override
  Future<void> deleteRecord(String id) => HikeService.delete(id);

  @override
  HikeRecord? findUnfinishedRecord() => HikeService.findUnfinished();
}
