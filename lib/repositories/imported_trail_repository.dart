import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../models/imported_trail.dart';
import '../models/osm_trail.dart';

/// Persists and retrieves [ImportedTrail] records from Hive.
///
/// All methods are static to match the project convention established by [HikeService].
class ImportedTrailRepository {
  static const String boxName = 'imported_trails';

  /// Incremented after every save() or delete(). Screens listen to this
  /// to know when to reload from Hive.
  static final ValueNotifier<int> version = ValueNotifier(0);

  /// Registers the [ImportedTrailAdapter] and opens the Hive box.
  ///
  /// Must be called after [Hive.initFlutter] and before any other
  /// repository method. Called once from [SplashScreen].
  static Future<void> init() async {
    Hive.registerAdapter(ImportedTrailAdapter());
    await Hive.openBox<ImportedTrail>(boxName);
  }

  /// Returns the open Hive box for imported trails.
  static Box<ImportedTrail> get _box => Hive.box<ImportedTrail>(boxName);

  /// Returns all imported trails, sorted by [ImportedTrail.importedAt]
  /// descending (newest first).
  static List<ImportedTrail> getAll() {
    final trails = _box.values.toList();
    trails.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return trails;
  }

  /// Persists an [ImportedTrail] to Hive, keyed by its [ImportedTrail.id].
  static Future<void> save(ImportedTrail trail) async {
    await _box.put(trail.id, trail);
    version.value++;
  }

  /// Deletes an imported trail by [id].
  static Future<void> delete(String id) async {
    await _box.delete(id);
    version.value++;
  }

  /// Converts an [ImportedTrail] to an [OsmTrail] for display.
  static OsmTrail toOsmTrail(ImportedTrail trail) {
    return OsmTrail(
      osmId: -trail.id.hashCode.abs(),
      name: trail.name,
      distanceKm: trail.distanceKm,
      difficulty: 'Imported',
      description: 'Imported from ${trail.sourceFilename}',
      geometry: List.generate(
        trail.latitudes.length,
        (i) => LatLng(trail.latitudes[i], trail.longitudes[i]),
      ),
      network: 'Unknown',
      operatorName: '',
      ref: '',
    );
  }
}
