import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/app_localizations.dart';
import '../models/weather_data.dart';
import '../services/compass_service.dart';
import '../services/hike_recording_controller.dart';
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
    await _controller.startRecording(
      onError: _showError,
      bgLocationDeniedMessage:
          AppLocalizations.of(context).trackBgLocationDenied,
      startFailedMessage: (detail) =>
          AppLocalizations.of(context).trackErrorCouldNotStart(detail),
    );
  }

  Future<void> _stopHike() async {
    final saved = await _controller.stopRecording(
      onError: _showError,
      saveFailedMessage: AppLocalizations.of(context).trackErrorCouldNotSave,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).trackHikeSaved)),
      );
    }
  }

  Future<void> _pauseHike() async {
    await _controller.pauseRecording();
  }

  Future<void> _resumeHike() async {
    await _controller.resumeRecording(onError: _showError);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trackAppBarTitle),
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
                          return _buildTile(theme, l10n.trackTileLat, lat);
                        },
                      ),
                      ValueListenableBuilder<LatLng?>(
                        valueListenable: _controller.positionNotifier,
                        builder: (context, pos, _) {
                          final lon = _controller.gpsAvailable && pos != null
                              ? pos.longitude.toStringAsFixed(4)
                              : '--';
                          return _buildTile(theme, l10n.trackTileLon, lon);
                        },
                      ),
                      ValueListenableBuilder<double>(
                        valueListenable: _controller.altitudeNotifier,
                        builder: (context, altitude, _) {
                          final alt = _controller.gpsAvailable
                              ? '${altitude.round()}m'
                              : '--';
                          return _buildTile(theme, l10n.trackTileAlt, alt);
                        },
                      ),
                      // TIME — recording-scoped
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          if (_controller.isRecording &&
                              _controller.inFlight != null) {
                            return _ElapsedTimeTile(
                              startTime: _controller.inFlight!.startTime,
                              label: l10n.trackTileTime,
                              isPaused: _controller.isPaused,
                            );
                          }
                          return _buildTile(theme, l10n.trackTileTime, '--');
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
                          return _buildTile(theme, l10n.trackTileDist, dist);
                        },
                      ),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final points = _controller.isRecording
                              ? '${_controller.pointCount}'
                              : '0';
                          return _buildTile(theme, l10n.trackTilePts, points);
                        },
                      ),
                      // TEMP, WEATHER, PRESSURE — weather-scoped
                      ValueListenableBuilder<WeatherData?>(
                        valueListenable: _controller.weatherNotifier,
                        builder: (context, weather, _) {
                          final temp = weather != null
                              ? '${weather.temperatureCelsius.toStringAsFixed(1)}\u00B0C'
                              : '--';
                          return _buildTile(theme, l10n.trackTileTemp, temp);
                        },
                      ),
                      ValueListenableBuilder<WeatherData?>(
                        valueListenable: _controller.weatherNotifier,
                        builder: (context, weather, _) {
                          final weatherDesc =
                              weather?.weatherDescription ?? '--';
                          return _buildTile(
                              theme, l10n.trackTileWeather, weatherDesc);
                        },
                      ),
                      ValueListenableBuilder<WeatherData?>(
                        valueListenable: _controller.weatherNotifier,
                        builder: (context, weather, _) {
                          final pressure = weather != null
                              ? weather.surfacePressureHpa.toStringAsFixed(1)
                              : '--';
                          return _buildTile(
                              theme, l10n.trackTilePressure, pressure);
                        },
                      ),
                      // STEPS, KCAL — steps-scoped
                      ValueListenableBuilder<StepData>(
                        valueListenable: _controller.stepsNotifier,
                        builder: (context, stepData, _) {
                          final stepsValue = _controller.pedometerAvailable
                              ? '${stepData.steps}'
                              : '--';
                          return _buildTile(
                              theme, l10n.trackTileSteps, stepsValue);
                        },
                      ),
                      ValueListenableBuilder<StepData>(
                        valueListenable: _controller.stepsNotifier,
                        builder: (context, stepData, _) {
                          final kcalValue = _controller.pedometerAvailable
                              ? stepData.calories.toStringAsFixed(1)
                              : '--';
                          return _buildTile(
                              theme, l10n.trackTileKcal, kcalValue);
                        },
                      ),
                      // SPEED — speed-scoped
                      ValueListenableBuilder<double>(
                        valueListenable: _controller.speedNotifier,
                        builder: (context, speed, _) {
                          final speedValue = _controller.isRecording &&
                                  _controller.gpsAvailable &&
                                  speed >= 0
                              ? (speed * 3.6).toStringAsFixed(1)
                              : '--';
                          return _buildTile(
                              theme,
                              l10n.trackTileSpeed,
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
                            l10n.trackTileGps,
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
            // --- Zone 3: Start/Stop/Pause/Resume buttons (fixed) ---
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final isRecording = _controller.isRecording;
                final isPaused = _controller.isPaused;
                final isSaving = _controller.isSaving;

                return Column(
                  children: [
                    if (!isRecording)
                      // Idle: full-width Start Hike button
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _startHike,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l10n.trackStartHike,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      )
                    else
                      // Recording or paused: two buttons side by side
                      SizedBox(
                        height: 64,
                        child: Row(
                          children: [
                            // Pause / Resume button
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : (isPaused ? _resumeHike : _pauseHike),
                                icon: Icon(isPaused
                                    ? Icons.play_arrow
                                    : Icons.pause),
                                label: Text(
                                  isPaused ? l10n.trackResume : l10n.trackPause,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stop & Save button
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: isSaving ? null : _stopHike,
                                icon: const Icon(Icons.stop),
                                label: Text(
                                  isSaving
                                      ? l10n.trackSaving
                                      : l10n.trackStopAndSave,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isRecording) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color:
                                  isPaused ? Colors.amber : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPaused
                                ? l10n.trackPaused
                                : l10n.trackRecording,
                            style: TextStyle(
                                color: isPaused
                                    ? Colors.amber
                                    : Colors.red),
                          ),
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
///
/// When [isPaused] is true, the timer freezes at the current elapsed value.
class _ElapsedTimeTile extends StatefulWidget {
  /// The moment the hike recording started (adjusted for pause durations).
  final DateTime startTime;

  /// Localised label for the tile (e.g. "TIME" / "TEMPO").
  final String label;

  /// When true, the timer is frozen at [startTime] offset and does not tick.
  final bool isPaused;

  const _ElapsedTimeTile({
    required this.startTime,
    required this.label,
    required this.isPaused,
  });

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
    if (!widget.isPaused) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(_ElapsedTimeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        _timer?.cancel();
        _timer = null;
        // Freeze at the current elapsed.
        setState(() => _elapsed = DateTime.now().difference(widget.startTime));
      } else {
        _startTimer();
      }
    }
    // startTime may be advanced on resume — recompute elapsed.
    if (oldWidget.startTime != widget.startTime && !widget.isPaused) {
      setState(() => _elapsed = DateTime.now().difference(widget.startTime));
    }
  }

  void _startTimer() {
    _timer?.cancel();
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
            widget.label,
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
