import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../models/imported_trail.dart';
import '../models/osm_trail.dart';
import '../services/imported_trail_service.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_preference_service.dart';
import '../utils/constants.dart';
import '../utils/map_utils.dart';
import '../widgets/map_attribution_widget.dart';
import 'trail_map_screen.dart';

class _ParseArgs {
  final String content;
  final String filename;
  const _ParseArgs(this.content, this.filename);
}

List<ImportedTrail> _parseGpxIsolate(_ParseArgs args) =>
    ImportedTrailService.parseGpx(args.content, args.filename);

List<ImportedTrail> _parseKmlIsolate(_ParseArgs args) =>
    ImportedTrailService.parseKml(args.content, args.filename);

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
  /// Uses ImportedTrail.id (String), not OsmTrail.osmId.
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
  ///
  /// Automatically exits selection mode when the last trail is deselected.
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

  /// Imports one or more GPX, KML, or XML files selected via the system
  /// file picker.
  ///
  /// Each file is independently validated and parsed. A summary [SnackBar]
  /// reports total trails imported, files processed, and any skipped/failed
  /// files.
  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return;

      int totalTrailsImported = 0;
      int filesProcessed = 0;
      int filesSkipped = 0;
      int filesFailed = 0;

      for (final file in result.files) {
        final extension = file.name.toLowerCase();

        // Validate extension — skip unsupported files
        if (!extension.endsWith('.gpx') &&
            !extension.endsWith('.kml') &&
            !extension.endsWith('.xml')) {
          filesSkipped++;
          continue;
        }

        try {
          if (file.bytes == null && file.path == null) {
            filesFailed++;
            continue;
          }

          final String content;
          if (file.bytes != null) {
            content = utf8.decode(file.bytes!);
          } else {
            content = await File(file.path!).readAsString();
          }

          // Dispatch to the correct parser based on file extension
          final List<ImportedTrail> parsed;
          if (extension.endsWith('.gpx')) {
            parsed = await compute(_parseGpxIsolate, _ParseArgs(content, file.name));
          } else {
            // .kml and .xml both contain KML content
            parsed = await compute(_parseKmlIsolate, _ParseArgs(content, file.name));
          }

          for (final trail in parsed) {
            await ImportedTrailService.save(trail);
          }

          totalTrailsImported += parsed.length;
          filesProcessed++;
        } on FormatException {
          filesFailed++;
        } catch (_) {
          filesFailed++;
        }
      }

      if (mounted) {
        // Build summary message
        final buf = StringBuffer(
          'Imported $totalTrailsImported trail${totalTrailsImported == 1 ? '' : 's'}'
          ' from $filesProcessed file${filesProcessed == 1 ? '' : 's'}',
        );
        if (filesSkipped > 0) {
          buf.write(' ($filesSkipped skipped: unsupported format)');
        }
        if (filesFailed > 0) {
          buf.write(' ($filesFailed failed to parse)');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(buf.toString())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Deletes an imported trail by [id] and refreshes the list.
  Future<void> _deleteImportedTrail(String id) async {
    await ImportedTrailService.delete(id);
    setState(() {
      // Close panel if the deleted trail was selected
      if (_selectedTrailId == id) {
        _panelVisible = false;
        _selectedTrail = null;
        _selectedTrailId = null;
      }
      // Remove from multi-select set; exit selection mode if empty
      _selectedIds.remove(id);
      if (_selectionMode && _selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  /// Shows a confirmation dialog before deleting an imported trail.
  ///
  /// Mirrors the Log screen's delete pattern for UX consistency.
  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trail?'),
        content: Text('Remove "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
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

  /// Looks up the [ImportedTrail] object for an imported trail by its ID.
  ///
  /// Returns `null` if [id] is null or no matching trail is found.
  ImportedTrail? _findImported(String? id, List<ImportedTrail> importedTrails) {
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

  /// Returns the list of trails to export based on the current mode.
  ///
  /// In selection mode, returns only selected trails. Otherwise returns all.
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

  /// Exports trails as GPX files, sharing a single file directly or
  /// bundling multiple files into a ZIP archive.
  ///
  /// In selection mode, exports only selected trails. Otherwise exports all.
  Future<void> _exportTrails() async {
    final trailsToExport = _trailsToExport;

    if (trailsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_selectionMode
                ? 'No trails selected.'
                : 'No trails to export.')),
      );
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

    try {
      final files =
          await ImportedTrailService.exportAllAsFiles(trailsToExport);
      if (!mounted) return;
      Navigator.pop(context); // dismiss dialog

      if (files.isEmpty) return;

      if (files.length == 1) {
        await Share.shareXFiles([XFile(files.first.path)]);
      } else {
        // Bundle into ZIP
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

      // Cleanup temp dir
      final exportDir =
          Directory('${(await getTemporaryDirectory()).path}/gpx_export');
      if (await exportDir.exists()) await exportDir.delete(recursive: true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Saves trails to a user-chosen folder via the native folder picker.
  ///
  /// In selection mode, saves only selected trails. Otherwise saves all.
  /// Shows a loading dialog during the operation and a SnackBar with the
  /// saved file path on success, or an error message on failure.
  Future<void> _saveTrailsToDevice() async {
    final trailsToExport = _trailsToExport;

    if (trailsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_selectionMode
                ? 'No trails selected.'
                : 'No trails to save.')),
      );
      return;
    }

    // Step 1: Open folder picker
    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return; // user cancelled

    // Step 2: WRITE_EXTERNAL_STORAGE is only needed on Android < 10 (API 28 and below).
    // On API 29+ scoped storage allows writing without this permission.
    if (Platform.isAndroid) {
      final sdkInt =
          (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdkInt < 29) {
        final status = await Permission.storage.request();
        if (!status.isGranted && !status.isLimited) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Storage permission required to save files')),
            );
          }
          return;
        }
      }
    }

    // Step 3: Show loading dialog
    if (!mounted) return;
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

    // Step 4: Write file(s) to chosen directory
    try {
      final path = await ImportedTrailService.saveAllToDirectory(
        trailsToExport,
        directoryPath,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $path')),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: ImportedTrailService.version,
              builder: (context, _) {
                final importedTrails = ImportedTrailService.getAll();
                return _buildBody(importedTrails);
              },
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
        tooltip: 'Import GPX / KML / XML',
        child: const Icon(Icons.file_upload),
      ),
    );
  }

  /// Builds the normal-mode AppBar with title and export menu.
  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: const Text('Trail Browser'),
      centerTitle: true,
      actions: [
        _buildExportMenu(),
      ],
    );
  }

  /// Builds the selection-mode AppBar with count, select-all toggle,
  /// and close button.
  PreferredSizeWidget _buildSelectionAppBar() {
    final importedCount = ImportedTrailService.getAll().length;
    final allSelected = _selectedIds.length == importedCount &&
        importedCount > 0;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedIds.length} selected'),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          onPressed: _toggleSelectAll,
        ),
        _buildExportMenu(),
      ],
    );
  }

  /// Builds the export [PopupMenuButton], shared by both AppBar modes.
  Widget _buildExportMenu() {
    final tooltip = _selectionMode
        ? 'Export ${_selectedIds.length} trail${_selectedIds.length == 1 ? '' : 's'}'
        : 'Export trails';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.file_download),
      tooltip: tooltip,
      onSelected: (value) {
        if (value == 'share') {
          _exportTrails();
        } else if (value == 'save') {
          _saveTrailsToDevice();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'share', child: Text('Share')),
        PopupMenuItem(value: 'save', child: Text('Save to device')),
      ],
    );
  }

  Widget _buildBody(List<ImportedTrail> importedTrails) {
    if (importedTrails.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No trails imported. Tap + to import a GPX, KML, or XML file.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      );
    }

    final trails = importedTrails.map((imported) => _DisplayTrail(
      osmTrail: ImportedTrailService.toOsmTrail(imported),
      importedTrailId: imported.id,
    )).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trails.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = trails[i];
        final t = item.osmTrail;
        final importedTrail = _findImported(item.importedTrailId, importedTrails);
        final isPreviewSelected =
            _selectedTrailId == item.importedTrailId && _panelVisible;
        final isChecked = _selectionMode &&
            _selectedIds.contains(item.importedTrailId);

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
                if (_selectedTrailId == item.importedTrailId && _panelVisible) {
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
                          tooltip: 'Start hike on this trail',
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
                          onPressed: () => _confirmDelete(
                              item.importedTrailId!, t.name),
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
                  // Import metadata rows (only for imported trails)
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

        // Wrap with selected indicator (preview highlight in normal mode)
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
        // Panel header
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
                tooltip: 'Full screen',
                onPressed: widget.onExpand,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Close',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        // Map
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                key: ValueKey(widget.trail.osmId),
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
        // Stats bar
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
///
/// When [importedTrailId] is non-null, the trail is user-imported.
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
