import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/hike_record.dart';
import '../models/weather_data.dart';
import '../utils/path_simplifier.dart';
import 'compass_service.dart';
import 'foreground_tracking_service.dart';
import 'hike_service.dart';
import 'location_service.dart';
import 'pedometer_service.dart';
import 'tracking_state.dart';
import 'weather_service.dart';

/// Approximate calories burned per step.
///
/// ~0.04 kcal/step assumes 75 kg walker (MET 3.5, ~100 steps/min).
const double kCaloriesPerStep = 0.04;

/// Immutable value object carrying step count and derived calories.
///
/// Used by [HikeRecordingController.stepsNotifier] to avoid separate
/// notifiers for steps and calories which always change together.
class StepData {
  /// Accumulated step count.
  final int steps;

  /// Derived calories burned from [steps].
  final double calories;

  const StepData({this.steps = 0, this.calories = 0.0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepData && steps == other.steps && calories == other.calories;

  @override
  int get hashCode => Object.hash(steps, calories);
}

/// Extracts all GPS recording business logic from `TrackScreen` into a
/// dedicated [ChangeNotifier].
///
/// Owns the compass subscription, weather polling timer, pedometer
/// subscription, foreground service lifecycle, and the mutable in-flight
/// [HikeRecord]. Position data is read from [TrackingState] (the single
/// shared GPS stream owner).
///
/// Instantiated once in `_HomePageState.initState()` and disposed in
/// `_HomePageState.dispose()`. Passed to [TrackScreen] as a constructor
/// parameter.
class HikeRecordingController extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Observable state
  // ---------------------------------------------------------------------------

  bool _isRecording = false;
  bool _isSaving = false;
  bool _gpsAvailable = false;
  bool _compassAvailable = true;
  bool _pedometerAvailable = true;
  double? _compassHeading;
  WeatherData? _weatherData;
  int _hikeSteps = 0;
  String? _lastError;

  /// The mutable in-flight record accumulating GPS points.
  HikeRecord? _inFlight;

  /// Whether a hike recording is currently in progress.
  bool get isRecording => _isRecording;

  /// Whether a save is in progress.
  bool get isSaving => _isSaving;

  /// True once the first GPS fix arrives.
  bool get gpsAvailable => _gpsAvailable;

  /// Most recent compass heading; null if no magnetometer.
  double? get compassHeading => _compassHeading;

  /// False if device has no magnetometer.
  bool get compassAvailable => _compassAvailable;

  /// Most recent successful weather fetch.
  WeatherData? get weatherData => _weatherData;

  /// Steps accumulated since recording started; 0 when idle.
  int get hikeSteps => _hikeSteps;

  /// Derived calories burned from step count.
  double get caloriesBurned => _hikeSteps * kCaloriesPerStep;

  /// False if sensor unavailable.
  bool get pedometerAvailable => _pedometerAvailable;

  /// Set when a recoverable error occurs; cleared on next start tap.
  String? get lastError => _lastError;

  /// The in-flight [HikeRecord] during recording, or `null` when idle.
  HikeRecord? get inFlight => _inFlight;

  /// Accumulated distance in metres during recording; 0.0 when idle.
  double get distanceMeters => _inFlight?.distanceMeters ?? 0.0;

  /// Number of GPS points collected so far.
  int get pointCount => _inFlight?.latitudes.length ?? 0;

  // ---------------------------------------------------------------------------
  // Per-subsystem notifiers for granular UI rebuilds
  // ---------------------------------------------------------------------------

  /// Compass heading; updated on every magnetometer event that exceeds 1-deg.
  final ValueNotifier<double?> headingNotifier = ValueNotifier(null);

  /// Latest ambient GPS position; updated on every [TrackingState] change.
  final ValueNotifier<LatLng?> positionNotifier = ValueNotifier(null);

  /// Step count and derived calories; updated on each pedometer event.
  final ValueNotifier<StepData> stepsNotifier =
      ValueNotifier(const StepData());

  /// Latest weather data; updated on each successful fetch.
  final ValueNotifier<WeatherData?> weatherNotifier = ValueNotifier(null);

  /// Most recent GPS accuracy radius in metres; updated on every fix.
  ///
  /// A value of 0.0 means no fix has arrived yet.
  final ValueNotifier<double> accuracyNotifier = ValueNotifier(0.0);

  // ---------------------------------------------------------------------------
  // Private fields
  // ---------------------------------------------------------------------------

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<({double lat, double lon})>? _recordingPointSub;
  Timer? _weatherTimer;
  LatLng? _lastWeatherPosition;
  StreamSubscription<int>? _stepSub;
  int _stepBaseline = 0;
  bool _stepBaselineSet = false;
  double? _lastSetHeading;

  // Weather fetch guard state
  bool _weatherFetchInProgress = false;
  DateTime? _lastWeatherTimerFire;

  // Checkpoint save state
  Timer? _checkpointTimer;
  int _pointsSinceCheckpoint = 0;
  static const int _kCheckpointInterval = 10;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises compass, pedometer probe, weather timer, and
  /// [TrackingState] listener.
  ///
  /// Called once from `TrackScreen.initState()`.
  Future<void> init() async {
    _initCompass();
    await _initPedometer();
    _recordingPointSub = TrackingState.instance.recordingPoints.listen(
      (event) => _onRecordingPoint(event.lat, event.lon),
    );
    TrackingState.instance.addListener(_onTrackingChanged);
    _onTrackingChanged(); // seed weather if position already available
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        _lastWeatherTimerFire = DateTime.now();
        _fetchWeather();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Compass
  // ---------------------------------------------------------------------------

  void _initCompass() {
    final stream = CompassService.headingStream;
    if (stream == null) {
      _compassAvailable = false;
      notifyListeners();
      return;
    }
    _compassSub = stream.listen(
      (event) {
        final h = event.heading;
        if (h == null) {
          if (_compassAvailable) {
            _compassAvailable = false;
            notifyListeners();
          }
          return;
        }
        if (_lastSetHeading == null || (h - _lastSetHeading!).abs() >= 1) {
          _lastSetHeading = h;
          _compassHeading = h;
          headingNotifier.value = h;
          if (!_compassAvailable) {
            _compassAvailable = true;
            notifyListeners();
          }
        }
      },
      onError: (_) {
        if (_compassAvailable) {
          _compassAvailable = false;
          notifyListeners();
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Pedometer
  // ---------------------------------------------------------------------------

  Future<void> _initPedometer() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      _pedometerAvailable = false;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('pedometer_available')) {
      _pedometerAvailable = prefs.getBool('pedometer_available') ?? true;
      notifyListeners();
      return;
    }

    // First launch: probe the sensor with a 500 ms timeout.
    try {
      final sub = PedometerService.stepCountStream.listen(
        (_) {},
        onError: (_) {
          _pedometerAvailable = false;
          notifyListeners();
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await sub.cancel();
    } catch (_) {
      _pedometerAvailable = false;
      notifyListeners();
    }
    await prefs.setBool('pedometer_available', _pedometerAvailable);
  }

  // ---------------------------------------------------------------------------
  // Weather
  // ---------------------------------------------------------------------------

  Future<void> _fetchWeather() async {
    if (_weatherFetchInProgress) return;
    final pos = TrackingState.instance.ambientPosition;
    if (pos == null) return;
    _weatherFetchInProgress = true;
    try {
      final data =
          await WeatherService.fetchCurrent(pos.latitude, pos.longitude);
      if (data != null) {
        _weatherData = data;
        _lastWeatherPosition = pos;
        weatherNotifier.value = data;
      }
    } finally {
      _weatherFetchInProgress = false;
    }
  }

  // ---------------------------------------------------------------------------
  // TrackingState listener
  // ---------------------------------------------------------------------------

  void _onTrackingChanged() {
    accuracyNotifier.value = TrackingState.instance.lastAccuracy;
    final pos = TrackingState.instance.ambientPosition;
    if (pos != null) {
      positionNotifier.value = pos;
      if (!_gpsAvailable) {
        _gpsAvailable = true;
        notifyListeners();
      }
      final timeSinceTimerFire = _lastWeatherTimerFire == null
          ? const Duration(days: 1)
          : DateTime.now().difference(_lastWeatherTimerFire!);
      if (timeSinceTimerFire > const Duration(minutes: 5) &&
          (_lastWeatherPosition == null ||
              LocationService.distanceBetween(
                    _lastWeatherPosition!.latitude,
                    _lastWeatherPosition!.longitude,
                    pos.latitude,
                    pos.longitude,
                  ) >
                  1000)) {
        unawaited(_fetchWeather());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Recording lifecycle
  // ---------------------------------------------------------------------------

  /// Starts a new hike recording session.
  ///
  /// [onError] is called when an error needs to surface to the user.
  Future<void> startRecording({
    required void Function(String message) onError,
  }) async {
    _lastError = null;
    try {
      final bgGranted = await ForegroundTrackingService.requestPermissions();
      if (!bgGranted) {
        onError(
          'For screen-off tracking, allow location access "All the time" in Settings.',
        );
      }
      await ForegroundTrackingService.start();
      await ForegroundTrackingService.setWakeLock(true);

      final record = HikeRecord(
        id: const Uuid().v4(),
        name:
            'Hike ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        startTime: DateTime.now(),
      );

      _inFlight = record;
      _hikeSteps = 0;
      _stepBaseline = 0;
      _stepBaselineSet = false;

      // Start pedometer for this hike.
      unawaited(_stepSub?.cancel() ?? Future.value());
      _stepSub = PedometerService.stepCountStream.listen(
        (steps) {
          if (!_stepBaselineSet) {
            _stepBaseline = steps;
            _stepBaselineSet = true;
          }
          _hikeSteps = max(0, steps - _stepBaseline);
          stepsNotifier.value = StepData(
            steps: _hikeSteps,
            calories: _hikeSteps * kCaloriesPerStep,
          );
        },
        onError: (_) {
          _pedometerAvailable = false;
          notifyListeners();
        },
      );

      _pointsSinceCheckpoint = 0;
      _checkpointTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          if (_inFlight != null) unawaited(_saveCheckpoint());
        },
      );

      _isRecording = true;
      notifyListeners();

      TrackingState.instance.startRecording();
    } catch (e) {
      _lastError = e.toString();
      onError('Could not start recording: $e');
      notifyListeners();
    }
  }

  void _onRecordingPoint(double lat, double lon) {
    if (_inFlight == null) return;
    if (_inFlight!.latitudes.isNotEmpty) {
      final dist = LocationService.distanceBetween(
        _inFlight!.latitudes.last,
        _inFlight!.longitudes.last,
        lat,
        lon,
      );
      _inFlight!.distanceMeters += dist;
    }
    _inFlight!.latitudes.add(lat);
    _inFlight!.longitudes.add(lon);
    notifyListeners();

    // Checkpoint save after every N points.
    _pointsSinceCheckpoint++;
    if (_pointsSinceCheckpoint >= _kCheckpointInterval) {
      unawaited(_saveCheckpoint());
    }

    if (_isRecording && _inFlight != null) {
      final elapsed = DateTime.now().difference(_inFlight!.startTime);
      ForegroundTrackingService.updateNotification(
        elapsed: elapsed,
        distanceMeters: _inFlight!.distanceMeters,
      );
    }
  }

  /// Writes the in-flight record to Hive as a checkpoint.
  ///
  /// Fire-and-forget; failures are logged but not surfaced to the user.
  Future<void> _saveCheckpoint() async {
    final record = _inFlight;
    if (record == null) return;
    _pointsSinceCheckpoint = 0;
    try {
      await HikeService.save(record);
    } catch (e) {
      debugPrint('Checkpoint save failed: $e');
    }
  }

  /// Stops the current recording session and persists the [HikeRecord].
  ///
  /// Returns the saved [HikeRecord] on success, or `null` if the save failed.
  /// On failure, [_inFlight] is preserved so the user can retry.
  Future<HikeRecord?> stopRecording({
    required void Function(String message) onError,
  }) async {
    _isSaving = true;
    notifyListeners();

    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    unawaited(_stepSub?.cancel() ?? Future.value());

    try {
      await ForegroundTrackingService.stop();
    } catch (_) {
      // Non-critical — service may already be stopped.
    }

    if (_inFlight != null) {
      _inFlight!.endTime = DateTime.now();
      _inFlight!.steps = _hikeSteps;
      _inFlight!.calories = _hikeSteps * kCaloriesPerStep;

      // Simplify the recorded route before final persistence.
      final simplified = simplifyHikeRecord(
        _inFlight!.latitudes,
        _inFlight!.longitudes,
      );
      _inFlight!.latitudes
        ..clear()
        ..addAll(simplified.latitudes);
      _inFlight!.longitudes
        ..clear()
        ..addAll(simplified.longitudes);

      try {
        await HikeService.save(_inFlight!);
      } catch (e) {
        // Roll back endTime so the record stays "in progress".
        _inFlight!.endTime = null;
        _lastError = 'Could not save hike. Please try again.';
        _isSaving = false;
        onError(_lastError!);
        notifyListeners();
        return null;
      }
    }

    final saved = _inFlight;

    TrackingState.instance.stopRecording();

    _isRecording = false;
    _isSaving = false;
    _inFlight = null;
    _hikeSteps = 0;
    _stepBaseline = 0;
    _stepBaselineSet = false;
    _weatherFetchInProgress = false;
    _lastWeatherTimerFire = null;
    _lastError = null;
    notifyListeners();

    return saved;
  }

  // ---------------------------------------------------------------------------
  // Crash recovery
  // ---------------------------------------------------------------------------

  /// Resumes recording from a previously checkpointed [HikeRecord].
  ///
  /// Restores the in-flight record, replays existing points into
  /// [TrackingState] for the map polyline, and starts the foreground
  /// service, pedometer, and checkpoint timer.
  Future<void> resumeFromRecord(
    HikeRecord record, {
    required void Function(String message) onError,
  }) async {
    try {
      TrackingState.instance.startRecording();
      final pts = List.generate(
        record.latitudes.length,
        (i) => LatLng(record.latitudes[i], record.longitudes[i]),
      );
      TrackingState.instance.replayPoints(pts);
      await ForegroundTrackingService.start();
      await ForegroundTrackingService.setWakeLock(true);

      _inFlight = record;
      _hikeSteps = 0;
      _stepBaseline = 0;
      _stepBaselineSet = false;
      _pointsSinceCheckpoint = 0;

      unawaited(_stepSub?.cancel() ?? Future.value());
      _stepSub = PedometerService.stepCountStream.listen(
        (steps) {
          if (!_stepBaselineSet) {
            _stepBaseline = steps;
            _stepBaselineSet = true;
          }
          _hikeSteps = max(0, steps - _stepBaseline);
          stepsNotifier.value = StepData(
            steps: _hikeSteps,
            calories: _hikeSteps * kCaloriesPerStep,
          );
        },
        onError: (_) {
          _pedometerAvailable = false;
          notifyListeners();
        },
      );

      _checkpointTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          if (_inFlight != null) unawaited(_saveCheckpoint());
        },
      );

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      TrackingState.instance.stopRecording();
      debugPrint('resumeFromRecord failed: $e');
      onError('Could not resume hike. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // Compass pause/resume (CR-2)
  // ---------------------------------------------------------------------------

  /// Pauses the compass subscription to conserve magnetometer power.
  ///
  /// Called by [_HomePageState] when the user navigates away from the
  /// Track tab.
  void pauseCompass() {
    _compassSub?.pause();
  }

  /// Resumes the compass subscription.
  ///
  /// Called by [_HomePageState] when the user returns to the Track tab.
  void resumeCompass() {
    if (_compassSub != null && _compassSub!.isPaused) {
      _compassSub!.resume();
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    TrackingState.instance.removeListener(_onTrackingChanged);
    _recordingPointSub?.cancel();
    _compassSub?.cancel();
    _weatherTimer?.cancel();
    _stepSub?.cancel();
    _checkpointTimer?.cancel();
    headingNotifier.dispose();
    positionNotifier.dispose();
    stepsNotifier.dispose();
    weatherNotifier.dispose();
    accuracyNotifier.dispose();
    super.dispose();
  }
}
