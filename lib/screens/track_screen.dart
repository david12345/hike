import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/weather_data.dart';
import '../services/compass_service.dart';
import '../services/hike_recording_controller.dart';
import '../services/tracking_state.dart';
import '../utils/constants.dart';
import '../widgets/compass_painter.dart';

/// Track screen with GPS tracking, live compass, coordinates, and altitude.
///
/// All recording business logic lives in [HikeRecordingController]. This
/// widget is display-only: it reads observable state from the controller
/// and renders the compass, data grid, and Start/Stop button.
///
/// The controller is owned by [_HomePageState] and passed as a constructor
/// parameter.
class TrackScreen extends StatefulWidget {
  /// The recording controller, owned by [_HomePageState].
  final HikeRecordingController controller;

  const TrackScreen({super.key, required this.controller});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  HikeRecordingController get _controller => widget.controller;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startHike() async {
    await _controller.startRecording(onError: _showError);
  }

  Future<void> _stopHike() async {
    final saved = await _controller.stopRecording(onError: _showError);
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hike saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Hike'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // --- Zone 1: Compass (flex: 3) ---
            Expanded(
              flex: 3,
              child: ValueListenableBuilder<double?>(
                valueListenable: _controller.headingNotifier,
                builder: (context, heading, _) {
                  final displayHeading = heading ?? 0.0;
                  final cardinal =
                      CompassService.headingToCardinal(displayHeading);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: CompassPainter(
                                  heading: heading,
                                  primaryColor:
                                      theme.colorScheme.onPrimaryContainer,
                                  accentColor: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _controller.compassAvailable && heading != null
                            ? '$cardinal ${heading.round() % 360}\u00B0'
                            : 'N/A',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // --- Zone 2: Data grid (flex: 5) ---
            Expanded(
              flex: 5,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 3;
                  const rows = 4;
                  const spacing = 8.0;
                  final tileWidth =
                      (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                          crossAxisCount;
                  final tileHeight =
                      (constraints.maxHeight - spacing * (rows - 1)) / rows;
                  final aspectRatio = tileWidth / tileHeight;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // LAT, LON, ALT — GPS position-scoped
                      ValueListenableBuilder<LatLng?>(
                        valueListenable: _controller.positionNotifier,
                        builder: (context, pos, _) {
                          final lat = _controller.gpsAvailable && pos != null
                              ? pos.latitude.toStringAsFixed(4)
                              : '--';
                          return _buildTile(theme, 'LAT', lat);
                        },
                      ),
                      ValueListenableBuilder<LatLng?>(
                        valueListenable: _controller.positionNotifier,
                        builder: (context, pos, _) {
                          final lon = _controller.gpsAvailable && pos != null
                              ? pos.longitude.toStringAsFixed(4)
                              : '--';
                          return _buildTile(theme, 'LON', lon);
                        },
                      ),
                      ValueListenableBuilder<LatLng?>(
                        valueListenable: _controller.positionNotifier,
                        builder: (context, pos, _) {
                          final tracking = TrackingState.instance;
                          final alt = _controller.gpsAvailable && pos != null
                              ? '${tracking.ambientAltitude.round()}m'
                              : '--';
                          return _buildTile(theme, 'ALT', alt);
                        },
                      ),
                      // TIME — recording-scoped
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          if (_controller.isRecording &&
                              _controller.inFlight != null) {
                            return _ElapsedTimeTile(
                                startTime: _controller.inFlight!.startTime);
                          }
                          return _buildTile(theme, 'TIME', '--');
                        },
                      ),
                      // DIST, PTS — recording-scoped
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final dist = _controller.isRecording
                              ? (_controller.inFlight?.distanceFormatted ??
                                  '0 m')
                              : '--';
                          return _buildTile(theme, 'DIST', dist);
                        },
                      ),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final points = _controller.isRecording
                              ? '${_controller.pointCount}'
                              : '0';
                          return _buildTile(theme, 'PTS', points);
                        },
                      ),
                      // TEMP, WEATHER, PRESSURE — weather-scoped
                      ValueListenableBuilder<WeatherData?>(
                        valueListenable: _controller.weatherNotifier,
                        builder: (context, weather, _) {
                          final temp = weather != null
                              ? '${weather.temperatureCelsius.toStringAsFixed(1)}\u00B0C'
                              : '--';
                          return _buildTile(theme, 'TEMP', temp);
                        },
                      ),
                      ValueListenableBuilder<WeatherData?>(
                        valueListenable: _controller.weatherNotifier,
                        builder: (context, weather, _) {
                          final weatherDesc =
                              weather?.weatherDescription ?? '--';
                          return _buildTile(theme, 'WEATHER', weatherDesc);
                        },
                      ),
                      ValueListenableBuilder<WeatherData?>(
                        valueListenable: _controller.weatherNotifier,
                        builder: (context, weather, _) {
                          final pressure = weather != null
                              ? weather.surfacePressureHpa.toStringAsFixed(1)
                              : '--';
                          return _buildTile(theme, 'PRESSURE', pressure);
                        },
                      ),
                      // STEPS, KCAL — steps-scoped
                      ValueListenableBuilder<StepData>(
                        valueListenable: _controller.stepsNotifier,
                        builder: (context, stepData, _) {
                          final stepsValue = _controller.pedometerAvailable
                              ? '${stepData.steps}'
                              : '--';
                          return _buildTile(theme, 'STEPS', stepsValue);
                        },
                      ),
                      ValueListenableBuilder<StepData>(
                        valueListenable: _controller.stepsNotifier,
                        builder: (context, stepData, _) {
                          final kcalValue = _controller.pedometerAvailable
                              ? stepData.calories.toStringAsFixed(1)
                              : '--';
                          return _buildTile(theme, 'KCAL', kcalValue);
                        },
                      ),
                      // SPEED — position-scoped
                      ValueListenableBuilder<LatLng?>(
                        valueListenable: _controller.positionNotifier,
                        builder: (context, pos, _) {
                          final tracking = TrackingState.instance;
                          final speedValue = _controller.isRecording &&
                                  _controller.gpsAvailable &&
                                  pos != null &&
                                  tracking.ambientSpeed >= 0
                              ? (tracking.ambientSpeed * 3.6)
                                  .toStringAsFixed(1)
                              : '--';
                          return _buildTile(
                              theme,
                              'SPEED',
                              speedValue == '--'
                                  ? '--'
                                  : '$speedValue km/h');
                        },
                      ),
                      // GPS accuracy — accuracy-scoped
                      ValueListenableBuilder<double>(
                        valueListenable: _controller.accuracyNotifier,
                        builder: (context, accuracy, _) {
                          final poor = accuracy > kMaxAcceptableAccuracyMetres;
                          final label = accuracy == 0.0
                              ? '--'
                              : '±${accuracy.toStringAsFixed(0)} m';
                          return _buildTile(
                            theme,
                            'GPS',
                            label,
                            warning: poor,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // --- Zone 3: Start/Stop button (fixed) ---
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: _controller.isRecording
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed:
                                  _controller.isSaving ? null : _stopHike,
                              icon: const Icon(Icons.stop),
                              label: Text(
                                _controller.isSaving
                                    ? 'Saving...'
                                    : 'Stop & Save',
                                style: const TextStyle(fontSize: 20),
                              ),
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _startHike,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Hike',
                                  style: TextStyle(fontSize: 20)),
                            ),
                    ),
                    if (_controller.isRecording) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Recording...',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Builds a uniform data tile for the grid.
  ///
  /// When [warning] is true the label is tinted amber to indicate degraded GPS.
  Widget _buildTile(ThemeData theme, String label, String value,
      {bool warning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: warning ? Colors.amber : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: warning ? Colors.amber : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-contained timer tile that rebuilds every second in isolation.
///
/// Owns its own [Timer] so the parent [_TrackScreenState] is not rebuilt
/// every second just for the elapsed-time display.
class _ElapsedTimeTile extends StatefulWidget {
  /// The moment the hike recording started.
  final DateTime startTime;

  const _ElapsedTimeTile({required this.startTime});

  @override
  State<_ElapsedTimeTile> createState() => _ElapsedTimeTileState();
}

class _ElapsedTimeTileState extends State<_ElapsedTimeTile> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(
            () => _elapsed = DateTime.now().difference(widget.startTime));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TIME',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatDuration(_elapsed),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
