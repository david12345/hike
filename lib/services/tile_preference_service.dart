import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// The three available map tile modes.
enum TileMode { osm, topo, satellite }

/// Observable singleton service for persisting the user's map tile preference
/// (standard OSM, OpenTopoMap, or satellite imagery).
///
/// Extends [ChangeNotifier] so screens can subscribe via [ListenableBuilder]
/// and rebuild only the tile-related subtree when the preference changes.
///
/// Must be initialized via [init] before use (called from `main()`).
class TilePreferenceService extends ChangeNotifier {
  TilePreferenceService._();

  /// The single shared instance.
  static final TilePreferenceService instance = TilePreferenceService._();

  static const String _key = 'tile_mode';
  static const String _legacyKey = 'use_topo_tiles';

  late SharedPreferences _prefs;
  TileMode _mode = TileMode.osm;

  /// Loads the saved preference. Awaited in main() before runApp().
  ///
  /// Migrates from the legacy bool key `use_topo_tiles` when the new key is
  /// absent: `true` maps to [TileMode.topo], `false` to [TileMode.osm].
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final storedName = _prefs.getString(_key);
    if (storedName != null) {
      _mode = TileMode.values.firstWhere(
        (m) => m.name == storedName,
        orElse: () => TileMode.osm,
      );
    } else {
      // Migrate from legacy bool key
      final legacyUseTopo = _prefs.getBool(_legacyKey);
      if (legacyUseTopo != null) {
        _mode = legacyUseTopo ? TileMode.topo : TileMode.osm;
        await _prefs.setString(_key, _mode.name);
        await _prefs.remove(_legacyKey);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The currently active tile mode.
  TileMode get mode => _mode;

  /// Whether the topo tile layer is currently active.
  bool get useTopo => _mode == TileMode.topo;

  /// Whether the satellite tile layer is currently active.
  bool get useSatellite => _mode == TileMode.satellite;

  /// Returns the tile URL template for the current mode.
  String get tileUrl {
    switch (_mode) {
      case TileMode.osm:
        return kOsmTileUrl;
      case TileMode.topo:
        return kTopoTileUrl;
      case TileMode.satellite:
        return kSatelliteTileUrl;
    }
  }

  /// Icon representing the mode the user will switch TO after the next tap.
  IconData get nextModeIcon {
    switch (_mode) {
      case TileMode.osm:
        return Icons.terrain;
      case TileMode.topo:
        return Icons.satellite_alt;
      case TileMode.satellite:
        return Icons.map;
    }
  }

  /// Tooltip describing the action of the next tap.
  String get nextModeTooltip {
    switch (_mode) {
      case TileMode.osm:
        return 'Switch to topo map';
      case TileMode.topo:
        return 'Switch to satellite';
      case TileMode.satellite:
        return 'Switch to standard map';
    }
  }

  // ---------------------------------------------------------------------------
  // Mutators
  // ---------------------------------------------------------------------------

  /// Persists an explicit [TileMode].
  ///
  /// No-op guard prevents redundant rebuilds when the value is unchanged.
  Future<void> setMode(TileMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _prefs.setString(_key, mode.name);
    notifyListeners();
  }

  /// Cycles through osm → topo → satellite → osm.
  Future<void> cycle() async {
    final next = TileMode.values[(_mode.index + 1) % TileMode.values.length];
    await setMode(next);
  }

  /// Alias for [cycle] — kept for backward compatibility.
  Future<void> toggle() => cycle();
}
