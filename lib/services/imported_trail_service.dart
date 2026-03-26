import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/hike_record.dart';
import '../models/imported_trail.dart';
import '../models/osm_trail.dart';
import '../parsers/gpx_parser.dart';
import '../parsers/kml_parser.dart';
import '../repositories/imported_trail_repository.dart';
import 'gpx_exporter.dart';

/// Facade for importing, persisting, and exporting hiking trails.
///
/// Delegates to [GpxParser], [KmlParser], [ImportedTrailRepository], and
/// [GpxExporter]. All methods remain static so existing call sites continue
/// to work without modification.
class ImportedTrailService {
  static const _uuid = Uuid();
  static const _gpxParser = GpxParser();
  static const _kmlParser = KmlParser();
  static const _exporter = GpxExporter();

  /// Incremented after every [save] or [delete]. Screens listen to this
  /// to know when to reload from Hive.
  static final ValueNotifier<int> version = ImportedTrailRepository.version;

  /// Returns all imported trails, sorted by [ImportedTrail.importedAt]
  /// descending (newest first).
  static List<ImportedTrail> getAll() => ImportedTrailRepository.getAll();

  /// Persists an [ImportedTrail] to Hive, keyed by its [ImportedTrail.id].
  static Future<void> save(ImportedTrail trail) =>
      ImportedTrailRepository.save(trail);

  /// Deletes an imported trail by [id].
  static Future<void> delete(String id) =>
      ImportedTrailRepository.delete(id);

  /// Parses a GPX XML string into a list of [ImportedTrail] (one per `<trk>`).
  ///
  /// Throws [FormatException] on malformed XML.
  static List<ImportedTrail> parseGpx(String xmlContent, String filename) =>
      _gpxParser.parse(xmlContent, filename);

  /// Parses a KML XML string into a list of [ImportedTrail].
  ///
  /// Throws [FormatException] on malformed XML.
  static List<ImportedTrail> parseKml(String xmlContent, String filename) =>
      _kmlParser.parse(xmlContent, filename);

  /// Converts an [ImportedTrail] to an [OsmTrail] for display.
  static OsmTrail toOsmTrail(ImportedTrail trail) =>
      ImportedTrailRepository.toOsmTrail(trail);

  /// Converts a [HikeRecord] to an [ImportedTrail] ready for persistence.
  ///
  /// The trail name can be overridden via [nameOverride].
  /// [ImportedTrail.sourceFilename] is set to `"Hike Log"` to distinguish
  /// from file imports.
  static ImportedTrail fromHikeRecord(
    HikeRecord hike, {
    String? nameOverride,
  }) {
    return ImportedTrail(
      id: _uuid.v4(),
      name: nameOverride ?? hike.name,
      latitudes: List<double>.from(hike.latitudes),
      longitudes: List<double>.from(hike.longitudes),
      distanceKm: hike.distanceMeters / 1000.0,
      importedAt: DateTime.now(),
      sourceFilename: 'Hike Log',
    );
  }

  /// Generates GPX 1.1 XML string for a single [ImportedTrail].
  static String exportToGpx(ImportedTrail trail) =>
      _exporter.toGpxString(trail);

  /// Writes each trail as a .gpx file in a temp directory.
  static Future<List<File>> exportAllAsFiles(List<ImportedTrail> trails) =>
      _exporter.exportAllAsFiles(trails);

  /// Saves all [trails] to the given [directoryPath].
  ///
  /// Single trail: saves as `<sanitized_name>.gpx`.
  /// Multiple trails: bundles into `hike_trails_<YYYYMMDD_HHmmss>.zip`.
  static Future<String> saveAllToDirectory(
    List<ImportedTrail> trails,
    String directoryPath,
  ) =>
      _exporter.saveAllToDirectory(trails, directoryPath);
}
