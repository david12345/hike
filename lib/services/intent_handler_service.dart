import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/imported_trail.dart';
import 'imported_trail_service.dart';

/// Handles Android file-open intents (ACTION_VIEW / ACTION_SEND) for
/// GPX, KML, and XML trail files.
///
/// Listens on a [MethodChannel] for file data pushed from [MainActivity].
/// On cold start, calls `getInitialFile` once to retrieve any pending file.
/// On warm start (app already running), the native side pushes `onNewFile`.
///
/// Set [onTrailsImported] and [onError] before calling [init] so the UI
/// callbacks are ready.
class IntentHandlerService {
  static const _channel = MethodChannel('com.dealmeida.hike/intent');

  /// Called after one or more trails are imported via an Android intent.
  /// Responsibility: navigate the UI to the Trails tab.
  /// Data reload is handled automatically by ImportedTrailService.version.
  static void Function()? onTrailsImported;

  /// Called when a file-open intent fails to parse or save.
  /// Registered by [_HomePageState.initState] to show a user-visible SnackBar.
  static void Function(String message)? onError;

  /// Initialises the service. Call once from [HomePage.initState].
  static Future<void> init() async {
    // Warm-start handler: native invokes this when onNewIntent fires.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewFile') {
        await _handleFileData(call.arguments as Map);
      }
    });

    // Cold-start: retrieve any file stored before Flutter was ready.
    final data = await _channel.invokeMethod<Map>('getInitialFile');
    if (data != null) {
      await _handleFileData(data);
    }
  }

  static Future<void> _handleFileData(Map data) async {
    final bytes = (data['bytes'] as List).cast<int>();
    final filename = (data['filename'] as String?) ?? 'trail.gpx';
    final content = utf8.decode(bytes);
    final ext = filename.toLowerCase();

    List<ImportedTrail> parsed;
    try {
      parsed = ext.endsWith('.gpx')
          ? ImportedTrailService.parseGpx(content, filename)
          : ImportedTrailService.parseKml(content, filename);
    } catch (e, stack) {
      debugPrint('IntentHandler: failed to parse "$filename": $e\n$stack');
      onError?.call('Could not read file "$filename": unrecognised format.');
      return;
    }

    try {
      for (final trail in parsed) {
        await ImportedTrailService.save(trail);
      }
    } catch (e, stack) {
      debugPrint('IntentHandler: failed to save trail from "$filename": $e\n$stack');
      onError?.call('Could not save trail from "$filename".');
      return;
    }

    if (parsed.isNotEmpty) {
      onTrailsImported?.call();
    }
  }
}
