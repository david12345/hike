import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/hike_record.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_preference_service.dart';
import '../utils/constants.dart';
import '../utils/map_utils.dart';

/// Detail screen for a saved hike showing an interactive map and stats.
class HikeDetailScreen extends StatefulWidget {
  final HikeRecord hike;
  const HikeDetailScreen({super.key, required this.hike});

  @override
  State<HikeDetailScreen> createState() => _HikeDetailScreenState();
}

class _HikeDetailScreenState extends State<HikeDetailScreen> {
  late final DraggableScrollableController _sheetController;

  /// Cached route points — computed once in [initState], never recomputed.
  /// HikeRecord coordinates are write-once; the screen is created fresh each
  /// time the user opens a hike from the log.
  late final List<LatLng> _route;

  /// Cached bounds — null when the route has fewer than 2 distinct points.
  late final LatLngBounds? _bounds;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _route = List.generate(
      widget.hike.latitudes.length,
      (i) => LatLng(widget.hike.latitudes[i], widget.hike.longitudes[i]),
    );
    _bounds = _hasMeaningfulBounds(_route) ? boundsForPoints(_route) : null;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// Whether the route has enough distinct points to compute meaningful bounds.
  bool _hasMeaningfulBounds(List<LatLng> route) {
    if (route.length < 2) return false;
    final first = route.first;
    return route.any(
      (p) => p.latitude != first.latitude || p.longitude != first.longitude,
    );
  }

  /// Fallback center when bounds cannot be computed.
  LatLng _fallbackCenter(List<LatLng> route) {
    if (route.isEmpty) return kFallbackLocation;
    return route.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = _route;
    final hasRoute = route.length > 1;
    final meaningfulBounds = _bounds != null;
    final pointCount = widget.hike.latitudes.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hike.name),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(
            child: hasRoute
                ? FlutterMap(
                    options: MapOptions(
                      initialCameraFit: meaningfulBounds
                          ? CameraFit.bounds(
                              bounds: _bounds,
                              padding:
                                  const EdgeInsets.fromLTRB(40, 40, 40, 200),
                            )
                          : null,
                      initialCenter: meaningfulBounds
                          ? const LatLng(0, 0)
                          : _fallbackCenter(route),
                      initialZoom: meaningfulBounds ? 14 : 16,
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
                            points: route,
                            color: Colors.blue,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: route.first,
                          child: const Icon(Icons.play_circle,
                              color: Colors.green, size: 24),
                        ),
                        Marker(
                          point: route.last,
                          child: const Icon(Icons.stop_circle,
                              color: Colors.red, size: 24),
                        ),
                      ]),
                    ],
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Text('No route recorded',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
          ),
          // Topo map toggle (only shown when route exists)
          if (hasRoute)
            ListenableBuilder(
              listenable: TilePreferenceService.instance,
              builder: (context, _) => Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'detail_topo',
                  onPressed: () => TilePreferenceService.instance.toggle(),
                  backgroundColor: TilePreferenceService.instance.useTopo
                      ? theme.colorScheme.primaryContainer
                      : null,
                  tooltip: 'Toggle topo map',
                  child: const Icon(Icons.terrain),
                ),
              ),
            ),
          // Draggable stats panel
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.35,
            minChildSize: 0.07,
            maxChildSize: 0.50,
            snap: true,
            snapSizes: const [0.07, 0.35],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'Date',
                              value: DateFormat('MMMM d, y')
                                  .format(widget.hike.startTime),
                            ),
                            _InfoRow(
                              icon: Icons.access_time,
                              label: 'Start',
                              value: DateFormat('HH:mm')
                                  .format(widget.hike.startTime),
                            ),
                            if (widget.hike.endTime != null)
                              _InfoRow(
                                icon: Icons.flag,
                                label: 'End',
                                value: DateFormat('HH:mm')
                                    .format(widget.hike.endTime!),
                              ),
                            _InfoRow(
                              icon: Icons.timer,
                              label: 'Duration',
                              value: widget.hike.durationFormatted,
                            ),
                            _InfoRow(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value: widget.hike.distanceFormatted,
                            ),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: 'GPS Points',
                              value: pointCount == 0
                                  ? 'No GPS points'
                                  : '$pointCount',
                            ),
                            if (widget.hike.steps > 0) ...[
                              _InfoRow(
                                icon: Icons.directions_walk,
                                label: 'Steps',
                                value: widget.hike.stepsFormatted,
                              ),
                              _InfoRow(
                                icon: Icons.local_fire_department,
                                label: 'Calories',
                                value: widget.hike.caloriesFormatted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A row displaying an icon, label, and value for the stats bottom sheet.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
