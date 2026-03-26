import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Observable singleton service for persisting the user's map tile preference
/// (standard OSM vs. OpenTopoMap).
///
/// Extends [ChangeNotifier] so screens can subscribe via [ListenableBuilder]
/// and rebuild only the tile-related subtree when the preference changes.
///
/// Must be initialized via [init] before use (called from `main()`).
class TilePreferenceService extends ChangeNotifier {
  TilePreferenceService._();

  /// The single shared instance.
  static final TilePreferenceService instance = TilePreferenceService._();

  static const String _key = 'use_topo_tiles';

  /// Standard OpenStreetMap tile URL template.
  static const String osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// OpenTopoMap tile URL template.
  static const String topoUrl = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';

  late SharedPreferences _prefs;
  bool _useTopo = false;

  /// Loads the saved preference. Awaited in main() before runApp().
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _useTopo = _prefs.getBool(_key) ?? false;
  }

  /// Whether the topo tile layer is currently active.
  bool get useTopo => _useTopo;

  /// Returns the current tile URL template based on the saved preference.
  String get tileUrl => _useTopo ? topoUrl : osmUrl;

  /// Persists the tile preference.
  ///
  /// No-op guard prevents redundant rebuilds when value is unchanged.
  Future<void> setUseTopo(bool value) async {
    if (_useTopo == value) return;
    _useTopo = value;
    await _prefs.setBool(_key, value);
    notifyListeners();
  }

  /// Toggles between OSM and OpenTopoMap tiles.
  Future<void> toggle() => setUseTopo(!_useTopo);
}
