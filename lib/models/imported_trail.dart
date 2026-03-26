import 'package:hive/hive.dart';

part 'imported_trail.g.dart';

/// A hiking trail imported from a local GPX or KML file.
///
/// Persisted in Hive with [typeId] 1 (see [HikeRecord] which uses 0).
/// GPS points are stored as parallel [latitudes] / [longitudes] lists
/// since [LatLng] is not a Hive-native type.
@HiveType(typeId: 1)
class ImportedTrail extends HiveObject {
  /// Unique identifier (UUID).
  @HiveField(0)
  String id;

  /// Trail name extracted from the file's `<name>` tag, or the filename
  /// if no name tag is present.
  @HiveField(1)
  String name;

  /// Latitude values for each GPS point (parallel array with [longitudes]).
  @HiveField(2)
  List<double> latitudes;

  /// Longitude values for each GPS point (parallel array with [latitudes]).
  @HiveField(3)
  List<double> longitudes;

  /// Total trail distance in kilometres, computed from geometry at import time.
  @HiveField(4)
  double distanceKm;

  /// Timestamp when the trail was imported (used for sorting, newest first).
  @HiveField(5)
  DateTime importedAt;

  /// Original filename for display in the trail description.
  @HiveField(6)
  String sourceFilename;

  ImportedTrail({
    required this.id,
    required this.name,
    required this.latitudes,
    required this.longitudes,
    required this.distanceKm,
    required this.importedAt,
    required this.sourceFilename,
  });
}
