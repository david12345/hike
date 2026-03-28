import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/osm_trail.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_preference_service.dart';
import '../utils/constants.dart';
import '../utils/map_utils.dart';
import '../widgets/map_attribution_widget.dart';

/// Full-screen map displaying a single [OsmTrail] route as a polyline.
///
/// Push-navigated from [TrailsScreen]. Includes a FAB to toggle between
/// standard OSM and topographic tiles.
class TrailMapScreen extends StatefulWidget {
  /// The trail to display.
  final OsmTrail trail;

  const TrailMapScreen({super.key, required this.trail});

  @override
  State<TrailMapScreen> createState() => _TrailMapScreenState();
}

class _TrailMapScreenState extends State<TrailMapScreen> {
  /// Computes the bounding box from the trail geometry.
  LatLngBounds get _bounds => boundsForPoints(widget.trail.geometry);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trail.name),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: _bounds,
                      padding: const EdgeInsets.all(40),
                    ),
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
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.trail.geometry.first,
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.play_circle,
                              color: Colors.green, size: 28),
                        ),
                        Marker(
                          point: widget.trail.geometry.last,
                          width: 30,
                          height: 30,
                          child: const Icon(Icons.stop_circle,
                              color: Colors.red, size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  '${widget.trail.distanceKm.toStringAsFixed(1)} km  |  ${widget.trail.difficulty}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const Positioned(
            top: 8,
            left: 8,
            child: MapAttributionWidget(),
          ),
          ListenableBuilder(
            listenable: TilePreferenceService.instance,
            builder: (context, _) => Positioned(
              bottom: 72,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'trail_topo',
                onPressed: () => TilePreferenceService.instance.cycle(),
                tooltip: TilePreferenceService.instance.nextModeTooltip,
                child: Icon(TilePreferenceService.instance.nextModeIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
