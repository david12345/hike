import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../models/export_format.dart';
import '../models/imported_trail.dart';
import 'imported_trail_service.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

sealed class ImportResult {
  const ImportResult();
}

class ImportSuccess extends ImportResult {
  /// Number of trails actually imported (across all files).
  final int count;

  /// Number of files successfully processed.
  final int filesProcessed;

  /// Number of files skipped due to unsupported extension.
  final int filesSkipped;

  /// Number of files that failed to parse.
  final int filesFailed;

  const ImportSuccess({
    required this.count,
    required this.filesProcessed,
    required this.filesSkipped,
    required this.filesFailed,
  });
}

class ImportCancelled extends ImportResult {
  const ImportCancelled();
}

class ImportFailure extends ImportResult {
  final String message;
  const ImportFailure(this.message);
}

sealed class ExportResult {
  const ExportResult();
}

class ExportSuccess extends ExportResult {
  const ExportSuccess();
}

class ExportEmpty extends ExportResult {
  const ExportEmpty();
}

class ExportFailure extends ExportResult {
  final String message;
  const ExportFailure(this.message);
}

sealed class SaveToDeviceResult {
  const SaveToDeviceResult();
}

class SaveToDeviceSuccess extends SaveToDeviceResult {
  final String path;
  const SaveToDeviceSuccess(this.path);
}

class SaveToDeviceCancelled extends SaveToDeviceResult {
  const SaveToDeviceCancelled();
}

class SaveToDevicePermissionDenied extends SaveToDeviceResult {
  const SaveToDevicePermissionDenied();
}

class SaveToDeviceFailure extends SaveToDeviceResult {
  final String message;
  const SaveToDeviceFailure(this.message);
}

// ---------------------------------------------------------------------------
// Isolate helpers — top-level for compute()
// ---------------------------------------------------------------------------

class _ParseArgs {
  final String content;
  final String filename;
  const _ParseArgs(this.content, this.filename);
}

List<ImportedTrail> _parseGpxIsolate(_ParseArgs args) =>
    ImportedTrailService.parseGpx(args.content, args.filename);

List<ImportedTrail> _parseKmlIsolate(_ParseArgs args) =>
    ImportedTrailService.parseKml(args.content, args.filename);

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Service that encapsulates all platform I/O for trail import and export.
///
/// No [BuildContext] dependency — results are returned as typed sealed classes
/// so callers can drive UI feedback without knowing platform details.
class TrailsImportExportService {
  const TrailsImportExportService._();

  static const TrailsImportExportService instance =
      TrailsImportExportService._();

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Opens the system file picker, parses selected GPX/KML/XML files, and
  /// saves the resulting trails to Hive via [ImportedTrailService].
  ///
  /// Returns an [ImportResult] describing the outcome.
  Future<ImportResult> importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) {
        return const ImportCancelled();
      }

      int totalTrailsImported = 0;
      int filesProcessed = 0;
      int filesSkipped = 0;
      int filesFailed = 0;

      for (final file in result.files) {
        final extension = file.name.toLowerCase();

        if (!extension.endsWith('.gpx') &&
            !extension.endsWith('.kml') &&
            !extension.endsWith('.xml')) {
          filesSkipped++;
          continue;
        }

        try {
          if (file.bytes == null && file.path == null) {
            filesFailed++;
            debugPrint('[TrailsImport] no data for file ${file.name}');
            continue;
          }

          final String content;
          if (file.bytes != null) {
            content = utf8.decode(file.bytes!);
          } else {
            content = await File(file.path!).readAsString();
          }

          final List<ImportedTrail> parsed;
          if (extension.endsWith('.gpx')) {
            parsed = await compute(
                _parseGpxIsolate, _ParseArgs(content, file.name));
          } else {
            parsed = await compute(
                _parseKmlIsolate, _ParseArgs(content, file.name));
          }

          for (final trail in parsed) {
            await ImportedTrailService.save(trail);
          }

          totalTrailsImported += parsed.length;
          filesProcessed++;
        } on FormatException catch (e) {
          filesFailed++;
          debugPrint('[TrailsImport] FormatException parsing ${file.name}: $e');
        } catch (e) {
          filesFailed++;
          debugPrint('[TrailsImport] unexpected error parsing ${file.name}: $e');
        }
      }

      return ImportSuccess(
        count: totalTrailsImported,
        filesProcessed: filesProcessed,
        filesSkipped: filesSkipped,
        filesFailed: filesFailed,
      );
    } catch (e) {
      debugPrint('[TrailsImport] import failed: $e');
      return ImportFailure('Import failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Export (share)
  // ---------------------------------------------------------------------------

  /// Exports [trails] via the system share sheet.
  ///
  /// [format] controls whether files are GPX (default) or KML.
  /// Single trail → shares file directly. Multiple trails → bundles into ZIP.
  Future<ExportResult> exportTrails(
    List<ImportedTrail> trails, {
    ExportFormat format = ExportFormat.gpx,
  }) async {
    if (trails.isEmpty) return const ExportEmpty();

    try {
      final files = await ImportedTrailService.exportAllAsFiles(
        trails,
        format: format,
      );
      if (files.isEmpty) return const ExportEmpty();

      if (files.length == 1) {
        final mimeType = format == ExportFormat.kml
            ? 'application/vnd.google-earth.kml+xml'
            : 'application/gpx+xml';
        await Share.shareXFiles(
          [XFile(files.first.path, mimeType: mimeType)],
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final zipPath = '${tempDir.path}/hike_trails.zip';
        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        for (final f in files) {
          await encoder.addFile(f);
        }
        await encoder.close();
        await Share.shareXFiles([XFile(zipPath)]);
      }

      // Cleanup temp export directory.
      final tempDir = await getTemporaryDirectory();
      final exportDirName =
          format == ExportFormat.kml ? 'kml_export' : 'gpx_export';
      final exportDir = Directory('${tempDir.path}/$exportDirName');
      if (await exportDir.exists()) await exportDir.delete(recursive: true);

      return const ExportSuccess();
    } catch (e) {
      debugPrint('[TrailsExport] export failed: $e');
      return ExportFailure('Export failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Save to device
  // ---------------------------------------------------------------------------

  /// Saves [trails] to a user-chosen folder on device storage.
  ///
  /// [format] controls whether files are GPX (default) or KML.
  /// On Android < API 29, requests WRITE_EXTERNAL_STORAGE permission first.
  Future<SaveToDeviceResult> saveTrailsToDevice(
    List<ImportedTrail> trails, {
    ExportFormat format = ExportFormat.gpx,
  }) async {
    if (trails.isEmpty) return const SaveToDeviceCancelled();

    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return const SaveToDeviceCancelled();

    if (Platform.isAndroid) {
      final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdkInt < 29) {
        final status = await Permission.storage.request();
        if (!status.isGranted && !status.isLimited) {
          debugPrint(
              '[TrailsSave] storage permission denied on SDK $sdkInt');
          return const SaveToDevicePermissionDenied();
        }
      }
    }

    try {
      final path = await ImportedTrailService.saveAllToDirectory(
        trails,
        directoryPath,
        format: format,
      );
      return SaveToDeviceSuccess(path);
    } catch (e) {
      debugPrint('[TrailsSave] save to device failed: $e');
      return SaveToDeviceFailure('Save failed: $e');
    }
  }
}
