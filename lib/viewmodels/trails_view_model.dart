import 'package:flutter/foundation.dart';

import '../models/imported_trail.dart';
import '../models/osm_trail.dart';
import '../services/imported_trail_service.dart';
import '../services/trails_import_export_service.dart';
import '../services/user_preferences_service.dart';

/// Display model pairing an [OsmTrail] with an optional imported trail ID.
class DisplayTrail {
  final OsmTrail osmTrail;
  final String? importedTrailId;

  const DisplayTrail({required this.osmTrail, this.importedTrailId});

  bool get isImported => importedTrailId != null;
}

/// ChangeNotifier ViewModel for [TrailsScreen].
///
/// Owns:
/// - The sorted [List<DisplayTrail>] derived from [ImportedTrailService].
/// - Multi-select state ([selectedIds], [isMultiSelectMode]).
/// - Preview panel state ([activePanelTrailId]).
/// - Delegation to [TrailsImportExportService] for import/export.
///
/// [TrailsScreen] becomes a pure [ListenableBuilder] view.
class TrailsViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  List<DisplayTrail> _trails = [];
  bool _isMultiSelectMode = false;
  final Set<String> _selectedIds = {};
  String? _activePanelTrailId;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The current sorted list of display trails.
  List<DisplayTrail> get trails => _trails;

  /// Whether multi-select mode is active.
  bool get isMultiSelectMode => _isMultiSelectMode;

  /// IDs of currently selected trails.
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  /// The ID of the trail whose preview panel is currently open, or null.
  String? get activePanelTrailId => _activePanelTrailId;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  TrailsViewModel() {
    ImportedTrailService.version.addListener(_onTrailsChanged);
    UserPreferencesService.instance.addListener(_onPrefsChanged);
    _rebuild();
  }

  @override
  void dispose() {
    ImportedTrailService.version.removeListener(_onTrailsChanged);
    UserPreferencesService.instance.removeListener(_onPrefsChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private rebuild
  // ---------------------------------------------------------------------------

  void _onTrailsChanged() => _rebuild();
  void _onPrefsChanged() => _rebuild();

  void _rebuild() {
    final all = ImportedTrailService.getAll();
    final sortAscending = UserPreferencesService.instance.trailsSortOrder ==
        TrailsSortOrder.ascending;
    final sorted = List<ImportedTrail>.from(all)
      ..sort((a, b) {
        final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return sortAscending ? cmp : -cmp;
      });
    _trails = sorted
        .map((t) => DisplayTrail(
              osmTrail: ImportedTrailService.toOsmTrail(t),
              importedTrailId: t.id,
            ))
        .toList();

    // Remove stale selections.
    final ids = _trails.map((t) => t.importedTrailId).toSet();
    _selectedIds.removeWhere((id) => !ids.contains(id));
    if (_selectedIds.isEmpty) _isMultiSelectMode = false;

    // Close panel if the selected trail was deleted.
    if (_activePanelTrailId != null && !ids.contains(_activePanelTrailId)) {
      _activePanelTrailId = null;
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Multi-select
  // ---------------------------------------------------------------------------

  void enterSelectionMode(String trailId) {
    _isMultiSelectMode = true;
    _selectedIds.add(trailId);
    _activePanelTrailId = null;
    notifyListeners();
  }

  void exitSelectionMode() {
    _isMultiSelectMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String trailId) {
    if (_selectedIds.contains(trailId)) {
      _selectedIds.remove(trailId);
      if (_selectedIds.isEmpty) _isMultiSelectMode = false;
    } else {
      _selectedIds.add(trailId);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (_selectedIds.length == _trails.length && _trails.isNotEmpty) {
      _selectedIds.clear();
      _isMultiSelectMode = false;
    } else {
      _selectedIds
        ..clear()
        ..addAll(_trails.map((t) => t.importedTrailId!).where((id) => id.isNotEmpty));
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Preview panel
  // ---------------------------------------------------------------------------

  void openPanel(String trailId) {
    _activePanelTrailId = trailId;
    notifyListeners();
  }

  void closePanel() {
    _activePanelTrailId = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Import / Export (delegate to TrailsImportExportService)
  // ---------------------------------------------------------------------------

  Future<ImportResult> importFile() =>
      TrailsImportExportService.instance.importFile();

  Future<ExportResult> exportTrails() {
    final trails = _trailsToExport;
    return TrailsImportExportService.instance.exportTrails(
      ImportedTrailService.getAll()
          .where((t) => trails.map((d) => d.importedTrailId).contains(t.id))
          .toList(),
    );
  }

  Future<SaveToDeviceResult> saveTrailsToDevice() {
    final trails = _trailsToExport;
    return TrailsImportExportService.instance.saveTrailsToDevice(
      ImportedTrailService.getAll()
          .where((t) => trails.map((d) => d.importedTrailId).contains(t.id))
          .toList(),
    );
  }

  List<DisplayTrail> get _trailsToExport =>
      _isMultiSelectMode ? _trails.where((t) => _selectedIds.contains(t.importedTrailId)).toList() : _trails;

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deleteTrail(String id) async {
    await ImportedTrailService.delete(id);
    // _rebuild() will be triggered by the version listener.
  }
}
