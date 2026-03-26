import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../models/imported_trail.dart';
import '../utils/map_utils.dart';

/// Parses GPX 1.1 XML text into [ImportedTrail] instances.
///
/// No dependencies on Hive, file I/O, or any Flutter plugin.
/// Safe to instantiate in plain Dart unit tests.
class GpxParser {
  const GpxParser();

  static const _uuid = Uuid();

  /// Parses [xmlContent] (a GPX 1.1 XML string) and returns one
  /// [ImportedTrail] per `<trk>` element.
  ///
  /// - Name: `<trk>/<name>`, falling back to [filename] without extension.
  /// - Coordinates: from `<trkseg>/<trkpt lat lon>` attributes.
  /// - Tracks with fewer than 2 valid points are skipped.
  ///
  /// Throws [FormatException] if [xmlContent] is not valid XML.
  List<ImportedTrail> parse(String xmlContent, String filename) {
    final document = XmlDocument.parse(xmlContent);
    final fallbackName = stripExtension(filename);
    final results = <ImportedTrail>[];

    final tracks = document.findAllElements('trk');
    for (final trk in tracks) {
      final nameElement = trk.findElements('name').firstOrNull;
      final name = nameElement?.innerText.trim().isNotEmpty == true
          ? nameElement!.innerText.trim()
          : fallbackName;

      final latitudes = <double>[];
      final longitudes = <double>[];

      final segments = trk.findElements('trkseg');
      for (final seg in segments) {
        for (final pt in seg.findElements('trkpt')) {
          final lat = double.tryParse(pt.getAttribute('lat') ?? '');
          final lon = double.tryParse(pt.getAttribute('lon') ?? '');
          if (lat != null && lon != null) {
            latitudes.add(lat);
            longitudes.add(lon);
          }
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

    return results;
  }

}
