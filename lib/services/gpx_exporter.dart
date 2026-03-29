import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/hike_record.dart';
import '../models/imported_trail.dart';

/// Serialises hiking trails to GPX 1.1 XML and manages export file I/O.
///
/// [toGpxString] and [hikeRecordToGpxString] are synchronous pure functions,
/// unit-testable without a real filesystem.
class GpxExporter {
  const GpxExporter();

  /// Returns a GPX 1.1 XML string for [trail].
  String toGpxString(ImportedTrail trail) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="Hike" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(trail.name)}</name>');
    buffer.writeln('    <trkseg>');
    _writeTrackPoints(buffer, trail.latitudes, trail.longitudes);
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.write('</gpx>');
    return buffer.toString();
  }

  /// Returns a GPX 1.1 XML string for [hike].
  ///
  /// NaN gap-marker coordinates inserted by the drift/gap-detection subsystems
  /// are silently skipped — they are invalid in the GPX 1.1 schema.
  String hikeRecordToGpxString(HikeRecord hike) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<gpx version="1.1" creator="Hike" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(hike.name)}</name>');
    buffer.writeln('    <trkseg>');
    _writeTrackPoints(buffer, hike.latitudes, hike.longitudes);
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.write('</gpx>');
    return buffer.toString();
  }

  /// Writes `<trkpt>` elements into [buf] for each (lat, lon) pair.
  ///
  /// Pairs where either coordinate is NaN (used as gap-markers) are skipped so
  /// the output is always valid GPX 1.1 XML.
  static void _writeTrackPoints(
      StringBuffer buf, List<double> lats, List<double> lons) {
    final count = lats.length < lons.length ? lats.length : lons.length;
    for (var i = 0; i < count; i++) {
      final lat = lats[i];
      final lon = lons[i];
      if (lat.isNaN || lon.isNaN) continue;
      buf.writeln('      <trkpt lat="$lat" lon="$lon"/>');
    }
  }

  /// Writes each trail in [trails] as a .gpx file under a temporary directory.
  Future<List<File>> exportAllAsFiles(List<ImportedTrail> trails) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/gpx_export');
    if (await exportDir.exists()) await exportDir.delete(recursive: true);
    await exportDir.create();

    final files = <File>[];
    final usedNames = <String>{};

    for (final trail in trails) {
      var baseName = _sanitizeFilename(trail.name);
      var fileName = '$baseName.gpx';
      var counter = 2;
      while (usedNames.contains(fileName)) {
        fileName = '${baseName}_$counter.gpx';
        counter++;
      }
      usedNames.add(fileName);

      final file = File('${exportDir.path}/$fileName');
      await file.writeAsString(toGpxString(trail));
      files.add(file);
    }

    return files;
  }

  /// Saves [trails] to [directoryPath].
  /// Single trail: written as `<name>.gpx`.
  /// Multiple trails: bundled into `hike_trails_<timestamp>.zip`.
  Future<String> saveAllToDirectory(
    List<ImportedTrail> trails,
    String directoryPath,
  ) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    if (trails.length == 1) {
      final trail = trails.first;
      final baseName = _sanitizeFilename(trail.name);
      final outFile = await _uniqueFile(directory, baseName, 'gpx');
      await outFile.writeAsString(toGpxString(trail));
      return outFile.path;
    }

    // Multiple trails -- write GPX files to temp, then bundle into ZIP
    final files = await exportAllAsFiles(trails);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final baseName = 'hike_trails_$timestamp';
    final outFile = await _uniqueFile(directory, baseName, 'zip');

    final encoder = ZipFileEncoder();
    encoder.create(outFile.path);
    for (final f in files) {
      await encoder.addFile(f);
    }
    await encoder.close();

    // Cleanup temp dir
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/gpx_export');
    if (await exportDir.exists()) await exportDir.delete(recursive: true);

    return outFile.path;
  }

  /// Returns a [File] in [directory] with the given [baseName] and
  /// [extension], appending `_2`, `_3`, etc. if a file already exists.
  static Future<File> _uniqueFile(
      Directory directory, String baseName, String extension) async {
    var file = File('${directory.path}/$baseName.$extension');
    var counter = 2;
    while (await file.exists()) {
      file = File('${directory.path}/${baseName}_$counter.$extension');
      counter++;
    }
    return file;
  }

  /// Sanitizes a trail name for use as a filename.
  static String _sanitizeFilename(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    return sanitized.isEmpty ? 'trail' : sanitized;
  }

  /// Escapes XML special characters in text content.
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
