import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/tile_cache_service.dart';
import '../services/tile_preference_service.dart';
import '../services/tracking_state.dart';
import '../utils/constants.dart';
import '../utils/map_utils.dart';
import '../widgets/map_attribution_widget.dart';

/// Live map screen showing the user's current GPS position on
/// OpenStreetMap tiles.
///
/// When a hike is being recorded via the Track screen, a live deepOrange
/// polyline is drawn over the collected GPS points. A FAB toggles between
/// standard OSM tiles and OpenTopoMap topographic tiles.
///
/// Position and heading are read from [TrackingState], the single shared
/// GPS stream owner. No own GPS subscription is opened.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _followLocation = true;

  @override
  void initState() {
    super.initState();
    TrackingState.instance.addListener(_onTrackingChanged);
  }

  /// Called when [TrackingState] fires [notifyListeners] — on every GPS event.
  ///
  /// Only pans the map camera; does NOT call [setState]. The [MarkerLayer] and
  /// [PolylineLayer] rebuild via their own [ListenableBuilder] wrappers.
  void _onTrackingChanged() {
    if (!mounted) return;
    final pos = TrackingState.instance.ambientPosition;
    if (_followLocation && pos != null) {
      _mapController.move(pos, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    TrackingState.instance.removeListener(_onTrackingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = TrackingState.instance.ambientPosition ?? kFallbackLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Map'), centerTitle: true),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _followLocation) {
                  setState(() => _followLocation = false);
                }
              },
            ),
            children: [
              // Tile layer — rebuilt only when tile preference changes.
              ListenableBuilder(
                listenable: TilePreferenceService.instance,
                builder: (context, _) => TileLayer(
                  urlTemplate: TilePreferenceService.instance.tileUrl,
                  userAgentPackageName: kPackageName,
                  tileProvider: TileCacheService.provider(),
                ),
              ),
              // GPS layers — rebuilt only on GPS events (not on setState).
              ListenableBuilder(
                listenable: TrackingState.instance,
                builder: (context, _) {
                  final tracking = TrackingState.instance;
                  final pos = tracking.ambientPosition;
                  final heading = tracking.ambientHeading;
                  final guide = tracking.activeGuideTrail;
                  return Stack(
                    children: [
                      if (guide != null &&
                          tracking.isRecording &&
                          guide.geometry.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: guide.geometry,
                              color: Colors.green,
                              strokeWidth: 3.0,
                            ),
                          ],
                        ),
                      if (tracking.isRecording &&
                          tracking.points.length > 1)
                        PolylineLayer(
                          polylines: segmentsFromPoints(tracking.points)
                              .map(
                                (seg) => Polyline(
                                  points: seg,
                                  color: Colors.deepOrange,
                                  strokeWidth: 4.0,
                                ),
                              )
                              .toList(),
                        ),
                      if (pos != null)
                        MarkerLayer(
                          markers: [
                            if (tracking.isRecording &&
                                tracking.points.isNotEmpty)
                              Marker(
                                point: tracking.points.first,
                                width: 30,
                                height: 30,
                                child: const Icon(
                                  Icons.play_circle,
                                  color: Colors.green,
                                  size: 28,
                                ),
                              ),
                            Marker(
                              point: pos,
                              width: 40,
                              height: 40,
                              child: _LocationMarker(
                                isRecording: tracking.isRecording,
                                heading: heading,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          const Positioned(
            top: 8,
            left: 8,
            child: MapAttributionWidget(),
          ),
          // Tile mode cycle FAB — rebuilt only when tile preference changes.
          ListenableBuilder(
            listenable: TilePreferenceService.instance,
            builder: (context, _) => Positioned(
              bottom: 72,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'topo',
                onPressed: () => TilePreferenceService.instance.cycle(),
                tooltip: TilePreferenceService.instance.nextModeTooltip,
                child: Icon(TilePreferenceService.instance.nextModeIcon),
              ),
            ),
          ),
          // Center / follow FAB — rebuilt only when _followLocation changes.
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'center',
              onPressed: () {
                final pos = TrackingState.instance.ambientPosition;
                if (pos != null) {
                  _mapController.move(pos, 15);
                  setState(() => _followLocation = true);
                }
              },
              child: Icon(
                _followLocation ? Icons.my_location : Icons.location_searching,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// GPS location marker that changes appearance based on recording state.
///
/// When recording and heading > 5 degrees, shows a rotated arrow pointing in the
/// direction of travel. Otherwise shows the default person_pin_circle icon.
/// Blue when idle, red when recording.
class _LocationMarker extends StatelessWidget {
  final bool isRecording;
  final double heading;

  const _LocationMarker({this.isRecording = false, this.heading = 0.0});

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? Colors.red : Colors.blue;

    if (isRecording && heading > 5.0) {
      return Transform.rotate(
        angle: heading * math.pi / 180,
        child: Icon(Icons.navigation, color: color, size: 32),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Icon(Icons.person_pin_circle, color: color, size: 24),
      ),
    );
  }
}
