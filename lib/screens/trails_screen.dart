import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/imported_trail.dart';
import '../models/osm_trail.dart';
import '../services/imported_trail_service.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_preference_service.dart';
import '../services/trails_import_export_service.dart';
import '../services/user_preferences_service.dart';
import '../utils/constants.dart';
import '../utils/map_utils.dart';
import '../widgets/map_attribution_widget.dart';
import 'trail_map_screen.dart';

/// Displays user-imported GPX trails from Hive.
///
/// Users can import GPX/KML/XML files via the FAB (single or multiple),
/// export all or selected trails, preview trails in a sliding bottom panel,
/// and delete imported trails with a confirmation dialog.
///
/// Long-pressing a trail card enters multi-select mode for batch export.
/// Tapping a trail opens a preview panel; tapping "full screen"
/// navigates to [TrailMapScreen].
class TrailsScreen extends StatefulWidget {
  /// Notifier written when the user taps "Start Hike" on a trail row.
  /// The parent [_HomePageState] listens and handles the recording start.
  final ValueNotifier<OsmTrail?> onStartHike;

  const TrailsScreen({super.key, required this.onStartHike});

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  OsmTrail? _selectedTrail;
  String? _selectedTrailId;
  bool _panelVisible = false;

  /// Whether the screen is in multi-select mode.
  bool _selectionMode = false;

  /// IDs of currently selected imported trails.
  final Set<String> _selectedIds = {};

  // ---------------------------------------------------------------------------
  // Selection mode helpers
  // ---------------------------------------------------------------------------

  /// Enters multi-select mode, selecting the trail with the given [trailId].
  void _enterSelectionMode(String trailId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(trailId);
      _panelVisible = false;
      _selectedTrail = null;
      _selectedTrailId = null;
    });
  }

  /// Exits multi-select mode and clears all selections.
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// Toggles the selection state of a single trail.
  void _toggleSelection(String trailId) {
    setState(() {
      if (_selectedIds.contains(trailId)) {
        _selectedIds.remove(trailId);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(trailId);
      }
    });
  }

  /// Toggles between selecting all and deselecting all trails.
  void _toggleSelectAll() {
    final importedTrails = ImportedTrailService.getAll();
    setState(() {
      if (_selectedIds.length == importedTrails.length) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(importedTrails.map((t) => t.id));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<void> _importFile() async {
    final result =
        await TrailsImportExportService.instance.importFile();

    if (!mounted) return;

    switch (result) {
      case ImportCancelled():
        break;
      case ImportSuccess(:final count, :final filesProcessed,
          :final filesSkipped, :final filesFailed):
        final l10n = AppLocalizations.of(context);
        final buf = StringBuffer(
          l10n.trailsImportSuccess(count, filesProcessed),
        );
        if (filesSkipped > 0) {
          buf.write(' (${l10n.trailsImportSkipped(filesSkipped)})');
        }
        if (filesFailed > 0) {
          buf.write(' (${l10n.trailsImportFailed(filesFailed)})');
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(buf.toString())));
      case ImportFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> _deleteImportedTrail(String id) async {
    await ImportedTrailService.delete(id);
    setState(() {
      if (_selectedTrailId == id) {
        _panelVisible = false;
        _selectedTrail = null;
        _selectedTrailId = null;
      }
      _selectedIds.remove(id);
      if (_selectionMode && _selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _confirmDelete(String id, String name) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trailsDeleteDialogTitle),
        content: Text(l10n.trailsDeleteDialogContent(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteImportedTrail(id);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ImportedTrail? _findImported(
      String? id, List<ImportedTrail> importedTrails) {
    if (id == null) return null;
    return importedTrails.firstWhereOrNull((t) => t.id == id);
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'Easy':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'Hard':
        return Colors.red;
      case 'Imported':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<ImportedTrail> get _trailsToExport {
    final importedTrails = ImportedTrailService.getAll();
    if (_selectionMode) {
      return importedTrails
          .where((t) => _selectedIds.contains(t.id))
          .toList();
    }
    return importedTrails;
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportTrails() async {
    final trails = _trailsToExport;

    if (trails.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_selectionMode
                  ? l10n.trailsNoTrailsSelected
                  : l10n.trailsNoTrailsToExport)),
        );
      }
      return;
    }

    // Show loading dialog
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Exporting trails...'),
          ],
        ),
      ),
    ));

    final result =
        await TrailsImportExportService.instance.exportTrails(trails);

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading dialog

    switch (result) {
      case ExportSuccess():
        break;
      case ExportEmpty():
        break;
      case ExportFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveTrailsToDevice() async {
    final trails = _trailsToExport;

    if (trails.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_selectionMode
                  ? l10n.trailsNoTrailsSelected
                  : l10n.trailsNoTrailsToExport)),
        );
      }
      return;
    }

    // Show loading dialog
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Saving trails...'),
          ],
        ),
      ),
    ));

    final result =
        await TrailsImportExportService.instance.saveTrailsToDevice(trails);

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading dialog

    final l10n = AppLocalizations.of(context);
    switch (result) {
      case SaveToDeviceSuccess(:final path):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.trailsSavedToPath(path))));
      case SaveToDeviceCancelled():
        break;
      case SaveToDevicePermissionDenied():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.trailsStoragePermissionRequired)),
        );
      case SaveToDeviceFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPreferencesService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: _selectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
          body: Column(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: ImportedTrailService.version,
                  builder: (context, _) =>
                      _buildBody(ImportedTrailService.getAll()),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _panelVisible
                    ? MediaQuery.of(context).size.height * 0.45
                    : 0,
                child: (_panelVisible && _selectedTrail != null)
                    ? _TrailPreviewPanel(
                        trail: _selectedTrail!,
                        importedTrailId: _selectedTrailId,
                        onExpand: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrailMapScreen(trail: _selectedTrail!),
                            ),
                          );
                        },
                        onClose: () => setState(() {
                          _panelVisible = false;
                          _selectedTrail = null;
                          _selectedTrailId = null;
                        }),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _importFile,
            tooltip: AppLocalizations.of(context).trailsImportTooltip,
            child: const Icon(Icons.file_upload),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    final l10n = AppLocalizations.of(context);
    final sortAscending = UserPreferencesService.instance.trailsSortOrder ==
        TrailsSortOrder.ascending;
    return AppBar(
      title: Text(l10n.trailsAppBarTitle),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
          tooltip: sortAscending ? l10n.trailsSortZtoA : l10n.trailsSortAtoZ,
          onPressed: UserPreferencesService.instance.toggleTrailsSortOrder,
        ),
        _buildExportMenu(),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final l10n = AppLocalizations.of(context);
    final importedCount = ImportedTrailService.getAll().length;
    final allSelected =
        _selectedIds.length == importedCount && importedCount > 0;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.trailsCancelSelection,
        onPressed: _exitSelectionMode,
      ),
      title: Text(l10n.trailsSelectionCount(_selectedIds.length)),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip:
              allSelected ? l10n.trailsDeselectAll : l10n.trailsSelectAll,
          onPressed: _toggleSelectAll,
        ),
        _buildExportMenu(),
      ],
    );
  }

  Widget _buildExportMenu() {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.file_download),
      tooltip: l10n.trailsExportTooltip,
      onSelected: (value) {
        if (value == 'share') {
          _exportTrails();
        } else if (value == 'save') {
          _saveTrailsToDevice();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'share', child: Text(l10n.trailsShareMenuItem)),
        PopupMenuItem(
            value: 'save', child: Text(l10n.trailsSaveToDeviceMenuItem)),
      ],
    );
  }

  Widget _buildBody(List<ImportedTrail> importedTrails) {
    final l10n = AppLocalizations.of(context);
    if (importedTrails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.trailsEmptyState,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }

    final sortAscending = UserPreferencesService.instance.trailsSortOrder ==
        TrailsSortOrder.ascending;

    final sorted = List<ImportedTrail>.from(importedTrails)
      ..sort((a, b) {
        final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return sortAscending ? cmp : -cmp;
      });

    final trails = sorted
        .map((imported) => _DisplayTrail(
              osmTrail: ImportedTrailService.toOsmTrail(imported),
              importedTrailId: imported.id,
            ))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trails.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = trails[i];
        final t = item.osmTrail;
        final importedTrail =
            _findImported(item.importedTrailId, importedTrails);
        final isPreviewSelected =
            _selectedTrailId == item.importedTrailId && _panelVisible;
        final isChecked =
            _selectionMode && _selectedIds.contains(item.importedTrailId);

        final card = Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onLongPress: () {
              if (item.isImported) {
                if (!_selectionMode) {
                  _enterSelectionMode(item.importedTrailId!);
                } else {
                  _toggleSelection(item.importedTrailId!);
                }
              }
            },
            onTap: () {
              if (_selectionMode) {
                if (item.isImported) {
                  _toggleSelection(item.importedTrailId!);
                }
              } else {
                if (_selectedTrailId == item.importedTrailId &&
                    _panelVisible) {
                  setState(() {
                    _panelVisible = false;
                    _selectedTrail = null;
                    _selectedTrailId = null;
                  });
                } else {
                  setState(() {
                    _selectedTrail = t;
                    _selectedTrailId = item.importedTrailId;
                    _panelVisible = true;
                  });
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_selectionMode)
                        Checkbox(
                          value: isChecked,
                          visualDensity: VisualDensity.compact,
                          onChanged: (_) {
                            if (item.isImported) {
                              _toggleSelection(item.importedTrailId!);
                            }
                          },
                        ),
                      Expanded(
                        child: Text(
                          t.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _difficultyColor(t.difficulty)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t.difficulty,
                          style: TextStyle(
                            color: _difficultyColor(t.difficulty),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (item.isImported && !_selectionMode)
                        IconButton(
                          icon: const Icon(Icons.directions_walk,
                              color: Colors.green),
                          tooltip: l10n.trailsStartHikeTooltip,
                          onPressed: () {
                            widget.onStartHike.value = t;
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (item.isImported)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              _confirmDelete(item.importedTrailId!, t.name),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Tag(Icons.straighten,
                          '${t.distanceKm.toStringAsFixed(1)} km'),
                      if (t.ref.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Flexible(child: _Tag(Icons.tag, t.ref)),
                      ],
                    ],
                  ),
                  if (t.operatorName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: _Tag(Icons.business, t.operatorName),
                        ),
                      ],
                    ),
                  ],
                  if (t.network != 'Unknown') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag(Icons.public, t.network),
                      ],
                    ),
                  ],
                  if (item.isImported && importedTrail != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: _Tag(Icons.insert_drive_file,
                              importedTrail.sourceFilename),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag(
                          Icons.calendar_today,
                          DateFormat('d MMM yyyy, HH:mm')
                              .format(importedTrail.importedAt),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        final wrappedCard = (!_selectionMode && isPreviewSelected)
            ? Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.deepOrange, width: 4),
                  ),
                ),
                child: card,
              )
            : card;

        return wrappedCard;
      },
    );
  }
}

class _TrailPreviewPanel extends StatefulWidget {
  final OsmTrail trail;
  final String? importedTrailId;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const _TrailPreviewPanel({
    required this.trail,
    this.importedTrailId,
    required this.onExpand,
    required this.onClose,
  });

  @override
  State<_TrailPreviewPanel> createState() => _TrailPreviewPanelState();
}

class _TrailPreviewPanelState extends State<_TrailPreviewPanel> {
  late final MapController _mapController;
  late final LatLngBounds _bounds;
  late final LatLng _centroid;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _bounds = boundsForPoints(widget.trail.geometry);
    _centroid = LatLng(
      (_bounds.south + _bounds.north) / 2,
      (_bounds.west + _bounds.east) / 2,
    );
    Future.delayed(const Duration(milliseconds: 350), _fitBounds);
  }

  @override
  void didUpdateWidget(_TrailPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.importedTrailId != widget.importedTrailId) {
      Future.delayed(const Duration(milliseconds: 350), _fitBounds);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitBounds() {
    if (!mounted) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: _bounds,
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Text(widget.trail.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis),
              ),
              ListenableBuilder(
                listenable: TilePreferenceService.instance,
                builder: (context, _) => IconButton(
                  icon: Icon(
                    TilePreferenceService.instance.nextModeIcon,
                    size: 20,
                  ),
                  tooltip: TilePreferenceService.instance.nextModeTooltip,
                  onPressed: () => TilePreferenceService.instance.cycle(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, size: 20),
                tooltip: AppLocalizations.of(context).trailsFullScreenTooltip,
                onPressed: widget.onExpand,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: AppLocalizations.of(context).trailsCloseTooltip,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centroid,
                  initialZoom: 10,
                ),
                children: [
                  ListenableBuilder(
                    listenable: TilePreferenceService.instance,
                    builder: (context, _) => TileLayer(
                      urlTemplate: TilePreferenceService.instance.tileUrl,
                      userAgentPackageName: kPackageName,
                      tileProvider: TileCacheService.provider(),
                    ),
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.trail.geometry,
                        color: Colors.deepOrange,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.trail.geometry.first,
                        width: 26,
                        height: 26,
                        child: const Icon(Icons.play_circle,
                            color: Colors.green, size: 24),
                      ),
                      Marker(
                        point: widget.trail.geometry.last,
                        width: 26,
                        height: 26,
                        child: const Icon(Icons.stop_circle,
                            color: Colors.red, size: 24),
                      ),
                    ],
                  ),
                ],
              ),
              const Positioned(
                top: 8,
                left: 8,
                child: MapAttributionWidget(),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '${widget.trail.distanceKm.toStringAsFixed(1)} km  |  ${widget.trail.difficulty}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

/// Internal wrapper pairing an [OsmTrail] with an optional imported trail ID.
class _DisplayTrail {
  final OsmTrail osmTrail;
  final String? importedTrailId;

  const _DisplayTrail({required this.osmTrail, this.importedTrailId});

  bool get isImported => importedTrailId != null;
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
