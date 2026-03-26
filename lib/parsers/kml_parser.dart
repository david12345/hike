import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../models/imported_trail.dart';
import '../utils/map_utils.dart';

/// Parses KML XML text into [ImportedTrail] instances.
///
/// No dependencies on Hive, file I/O, or any Flutter plugin.
/// Safe to instantiate in plain Dart unit tests.
class KmlParser {
  const KmlParser();

  static const _uuid = Uuid();

  /// Parses [xmlContent] (a KML XML string) and returns one [ImportedTrail]
  /// per `<Placemark>` that contains a `<LineString>`.
  ///
  /// - Name: `<Placemark>/<name>`, falling back to [filename] without extension.
  /// - Coordinates: from `<LineString>/<coordinates>` text.
  ///   KML coordinate order is `lon,lat[,alt]` -- longitude comes first.
  /// - Placemarks with fewer than 2 valid points are skipped.
  ///
  /// Throws [FormatException] if [xmlContent] is not valid XML.
  List<ImportedTrail> parse(String xmlContent, String filename) {
    final document = XmlDocument.parse(xmlContent);
    final fallbackName = stripExtension(filename);
    final results = <ImportedTrail>[];

    final placemarks = document.findAllElements('Placemark');
    for (final pm in placemarks) {
      final lineStrings = pm.findElements('LineString');
      if (lineStrings.isEmpty) continue;

      final nameElement = pm.findElements('name').firstOrNull;
      final name = nameElement?.innerText.trim().isNotEmpty == true
          ? nameElement!.innerText.trim()
          : fallbackName;

      for (final ls in lineStrings) {
        final coordsElement = ls.findElements('coordinates').firstOrNull;
        if (coordsElement == null) continue;

        final latitudes = <double>[];
        final longitudes = <double>[];

        final entries = coordsElement.innerText.trim().split(RegExp(r'\s+'));
        for (final entry in entries) {
          if (entry.isEmpty) continue;
          final parts = entry.split(',');
          if (parts.length < 2) continue;
          final lon = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat != null && lon != null) {
            latitudes.add(lat);
            longitudes.add(lon);
          }
        }

        if (latitudes.length < 2) continue;

        results.add(ImportedTrail(
          id: _uuid.v4(),
          name: name,
          latitudes: latitudes,
          longitudes: longitudes,
          distanceKm: computeDistanceKm(latitudes, longitudes),
          importedAt: DateTime.now(),
          sourceFilename: filename,
        ));
      }
    }

    return results;
  }

}
