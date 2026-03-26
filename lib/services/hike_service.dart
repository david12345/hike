import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hike_record.dart';

class HikeService {
  static const _boxName = 'hikes';

  /// Incremented after every save() or delete(). Screens listen to this
  /// to know when to reload from Hive.
  static final ValueNotifier<int> version = ValueNotifier(0);

  static Future<void> init() async {
    Hive.registerAdapter(HikeRecordAdapter());
    await Hive.openBox<HikeRecord>(_boxName);
  }

  static Box<HikeRecord> get _box => Hive.box<HikeRecord>(_boxName);

  static List<HikeRecord> getAll() {
    return _box.values.toList().reversed.toList();
  }

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
}
