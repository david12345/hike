import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/osm_trail.dart';
import '../utils/constants.dart';
import 'location_service.dart';

/// EMA smoothing factor for GPS altitude readings.
///
/// At alpha = 0.2, each raw fix contributes 20% to the smoothed altitude,
/// reducing +-10-30 m jitter to a stable, readable value within 3-4 fixes.
const double _kAltitudeEmaAlpha = 0.2;

/// Number of consecutive accuracy-gated fixes before emitting a single
/// consolidated warning to the debug log.
const int _kConsecutiveDropThreshold = 5;

/// A GPS fix held in the adaptive accuracy buffer.
class _BufferedFix {
  final double lat;
  final double lon;
  final double accuracy;
  final double heading;
  final DateTime receivedAt;

  const _BufferedFix({
    required this.lat,
    required this.lon,
    required this.accuracy,
    required this.heading,
    required this.receivedAt,
  });
}

/// Singleton service that shares live hike-recording state between screens
/// and owns the single device GPS stream.
///
/// Two stream modes are managed internally:
/// - **Ambient** (`LocationAccuracy.medium`, 50 m filter) — active when not
///   recording. Provides position updates for the map dot and coordinate tiles.
/// - **Recording** (`LocationAccuracy.high`, 5 m filter) — active while a hike
///   is being recorded. Each event is also added to the live polyline.
///
/// No other class should call [LocationService.trackPosition] or
/// [LocationService.trackPositionAmbient] directly.
class TrackingState extends ChangeNotifier with WidgetsBindingObserver {
  TrackingState._();

  /// The single shared instance.
  static final TrackingState instance = TrackingState._();

  bool _isRecording = false;
  final List<LatLng> _points = [];
  LatLng? _currentPosition;
  OsmTrail? _activeGuideTrail;

  /// Cached unmodifiable view of [_points]. Invalidated on mutation.
  List<LatLng>? _pointsCache;

  /// The active GPS stream subscription (ambient or recording).
  StreamSubscription<Position>? _streamSub;

  /// The last known position from either stream mode.
  LatLng? _ambientPosition;

  /// The last known bearing from [Position.heading], in degrees.
  double _ambientHeading = 0.0;

  /// The last known altitude in metres.
  double _ambientAltitude = 0.0;

  /// The last known speed in m/s.
  double _ambientSpeed = 0.0;

  /// Whether location permission was granted during [init].
  bool _permissionGranted = false;

  /// The most recent horizontal accuracy radius in metres.
  ///
  /// Updated on every GPS event regardless of whether the fix was accepted.
  double _lastAccuracy = 0.0;

  /// Counter of consecutive fixes dropped by the accuracy gate.
  int _consecutiveDropped = 0;

  /// Wall time of the last accepted GPS fix during recording.
  DateTime? _lastAcceptedFixAt;

  /// Whether a gap marker was just inserted (suppresses duplicate gap checks).
  bool _gapJustInserted = false;

  /// Poor-quality fixes held while waiting for signal recovery.
  final List<_BufferedFix> _accuracyBuffer = [];

  /// Whether the recording stream is currently in low-frequency stationary mode.
  bool _stationaryMode = false;

  /// Number of consecutive accepted fixes below [kStationarySpeedThreshold].
  ///
  /// When this exceeds `kStationaryDebounceSecs / kRecordingTimeIntervalSeconds`
  /// the stream switches to stationary mode.
  int _stationaryCounter = 0;

  /// Wall time when the first buffered fix was received.
  DateTime? _bufferStartedAt;

  /// Compass bearing (degrees) at the most recently accepted GPS fix.
  ///
  /// Null until the first fix is accepted in a recording session. Reset to
  /// null on [startRecording] and [stopRecording] to prevent stale headings
  /// from a previous session influencing the next one.
  double? _lastRecordedHeading;

  /// Broadcast stream that emits each raw GPS fix during recording.
  ///
  /// Subscribed to by [HikeRecordingController] to update distance and
  /// coordinates on the in-flight [HikeRecord].
  final StreamController<({double lat, double lon})>
      _recordingPointController = StreamController.broadcast();

  /// Stream of raw GPS fixes during recording.
  Stream<({double lat, double lon})> get recordingPoints =>
      _recordingPointController.stream;

  /// Whether a hike recording is currently in progress.
  bool get isRecording => _isRecording;

  /// The trail selected as a guide for the current recording session.
  /// Non-null while recording started via the Trails screen.
  /// Always null when not recording.
  OsmTrail? get activeGuideTrail => _activeGuideTrail;

  /// An unmodifiable snapshot of all GPS points collected during the
  /// current recording session. Empty when not recording.
  ///
  /// Returns the same object reference between mutations, avoiding
  /// per-access allocation of a new [List.unmodifiable] wrapper.
  List<LatLng> get points => _pointsCache ??= List.unmodifiable(_points);

  /// The most recent GPS position during recording, or `null` when idle.
  LatLng? get currentPosition => _currentPosition;

  /// The last known position in either stream mode.
  ///
  /// Returns `null` before the first GPS fix.
  LatLng? get ambientPosition => _ambientPosition;

  /// The last known bearing from [Position.heading], in degrees.
  ///
  /// Defaults to `0.0` before the first fix.
  double get ambientHeading => _ambientHeading;

  /// The last known altitude in metres.
  double get ambientAltitude => _ambientAltitude;

  /// The last known speed in m/s.
  double get ambientSpeed => _ambientSpeed;

  /// The most recent horizontal accuracy radius in metres.
  ///
  /// Updated on every GPS event, regardless of whether the fix was accepted
  /// into the recorded route. Returns 0.0 before the first fix.
  double get lastAccuracy => _lastAccuracy;

  /// Requests location permission and starts the ambient GPS stream.
  ///
  /// Call once from [SplashScreen.initState].
  static Future<void> init() async {
    instance._permissionGranted = await LocationService.requestPermission();
    WidgetsBinding.instance.addObserver(instance);
    if (instance._permissionGranted) {
      instance._startAmbientStream();
    }
  }

  /// Sets the guide trail for the upcoming recording session.
  ///
  /// Called from [_HomePageState] before [startRecording] so that
  /// [MapScreen] can render the reference polyline immediately when
  /// recording begins.
  void setGuideTrail(OsmTrail? trail) {
    _activeGuideTrail = trail;
    notifyListeners();
  }

  /// Begins a new recording session, clearing any previous state.
  ///
  /// Swaps from the ambient stream to the high-accuracy recording stream.
  void startRecording() {
    _isRecording = true;
    _points.clear();
    _pointsCache = null;
    _currentPosition = null;
    _ambientAltitude = 0.0; // reset EMA for fresh recording baseline
    _lastAcceptedFixAt = null;
    _gapJustInserted = false;
    _accuracyBuffer.clear();
    _bufferStartedAt = null;
    _lastRecordedHeading = null;
    _stationaryMode = false;
    _stationaryCounter = 0;
    _startRecordingStream();
    notifyListeners();
  }

  /// Appends a GPS point to the live polyline and updates [currentPosition].
  ///
  /// Called internally from the recording stream listener each time
  /// the device moves at least 5 m (the configured `distanceFilter`).
  void addPoint(double latitude, double longitude) {
    assert(!latitude.isNaN && !longitude.isNaN,
        'addPoint called with NaN — use _insertGapMarker() instead');
    final point = LatLng(latitude, longitude);
    _points.add(point);
    _pointsCache = null;
    _currentPosition = point;
    _gapJustInserted = false;
    notifyListeners();
  }

  /// Replays a batch of historical GPS points into the live polyline
  /// with a single [notifyListeners] call at the end.
  ///
  /// Used by [HikeRecordingController.resumeFromRecord] to restore
  /// checkpointed points without O(N) synchronous listener dispatches.
  void replayPoints(List<LatLng> pts) {
    _points.addAll(pts);
    _pointsCache = null;
    if (pts.isNotEmpty) {
      _currentPosition = pts.last;
      notifyListeners();
    }
  }

  /// Ends the current recording session and clears polyline state.
  ///
  /// Swaps back to the ambient (low-power) GPS stream.
  void stopRecording() {
    _isRecording = false;
    _points.clear();
    _pointsCache = null;
    _currentPosition = null;
    _activeGuideTrail = null;
    _lastAcceptedFixAt = null;
    _gapJustInserted = false;
    _accuracyBuffer.clear();
    _bufferStartedAt = null;
    _lastRecordedHeading = null;
    _stationaryMode = false;
    _stationaryCounter = 0;
    _startAmbientStream();
    notifyListeners();
  }

  /// Resets the last-accepted-fix timestamp so the next fix does not
  /// trigger a gap marker after a deliberate user pause.
  ///
  /// Call immediately before re-subscribing to [recordingPoints] in
  /// [HikeRecordingController.resumeRecording].
  void resetGapTimer() {
    _lastAcceptedFixAt = DateTime.now();
    _gapJustInserted = false;
  }

  /// Cancels the active GPS subscription and closes the recording point
  /// stream controller.
  ///
  /// Called from [_HomePageState.dispose] on app exit to release the
  /// platform GPS stream cleanly.
  void cancelStream() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSub?.cancel();
    _streamSub = null;
    _recordingPointController.close();
  }

  // ---------------------------------------------------------------------------
  // App lifecycle observer (H4)
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_isRecording) {
        _pauseAmbient();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isRecording && _streamSub == null && _permissionGranted) {
        _resumeAmbient();
      }
    }
  }

  void _pauseAmbient() {
    debugPrint('[TrackingState] ambient GPS paused (app backgrounded)');
    _streamSub?.cancel();
    _streamSub = null;
  }

  void _resumeAmbient() {
    debugPrint('[TrackingState] ambient GPS resumed (app foregrounded)');
    _startAmbientStream();
  }

  // ---------------------------------------------------------------------------
  // Private stream management
  // ---------------------------------------------------------------------------

  /// Starts the low-power ambient GPS stream.
  void _startAmbientStream() {
    _streamSub?.cancel();
    _streamSub = LocationService.trackPositionAmbient().listen(
      (pos) {
        _updateFromPosition(pos);
        notifyListeners();
      },
    );
  }

  /// Appends a sentinel LatLng(double.nan, double.nan) to mark a tracking gap.
  ///
  /// Renderers that consume [points] must split the list at NaN sentinels
  /// and draw separate polyline segments.
  void _insertGapMarker() {
    _points.add(const LatLng(double.nan, double.nan));
    _pointsCache = null;
    _gapJustInserted = true;
  }

  /// Accepts a fix into the route, checking for a time gap first.
  ///
  /// [heading] is the [Position.heading] of the accepted fix. It is stored in
  /// [_lastRecordedHeading] so that the next fix can compute a heading delta
  /// via [_headingDelta] and detect curve-triggered recording points.
  void _acceptFix(double lat, double lon, double heading, DateTime now) {
    if (!_gapJustInserted && _lastAcceptedFixAt != null) {
      final gapSeconds = now.difference(_lastAcceptedFixAt!).inSeconds;
      if (gapSeconds >= kGapThresholdSeconds) {
        _insertGapMarker();
      }
    }
    _lastAcceptedFixAt = now;
    _lastRecordedHeading = heading;
    if (!_recordingPointController.isClosed) {
      _recordingPointController.add((lat: lat, lon: lon));
    }
    addPoint(lat, lon);
  }

  /// Returns the absolute angular difference between [current] and [last],
  /// in the range 0–180 degrees, with correct 0°/360° wrap-around handling.
  ///
  /// Returns 0.0 if [last] is null (first fix in the session) or if [current]
  /// is negative (some chipsets return -1.0 as an "invalid heading" sentinel
  /// when speed is too low to compute a reliable bearing).
  double _headingDelta(double current, double? last) {
    if (last == null) return 0.0;
    if (current < 0) return 0.0;
    final delta = (current - last).abs() % 360;
    return delta > 180 ? 360 - delta : delta;
  }

  /// Starts the high-accuracy recording GPS stream in moving (high-frequency)
  /// mode.
  ///
  /// Fixes with [Position.accuracy] > [kMaxAcceptableAccuracyMetres] are
  /// held in a short adaptive buffer waiting for recovery. If signal recovers
  /// within [kAdaptiveBufferWindowSeconds], the best buffered fix is committed
  /// before the new good fix. If not, the buffer is flushed and a gap marker
  /// is inserted.
  void _startRecordingStream() {
    _streamSub?.cancel();
    _consecutiveDropped = 0;
    _streamSub = LocationService.trackPosition().listen(_onRecordingFix);
  }

  /// Switches the recording stream to low-frequency stationary mode.
  ///
  /// Called after the hiker has remained below [kStationarySpeedThreshold]
  /// for [kStationaryDebounceSecs] consecutive seconds.
  /// [_lastAcceptedFixAt] is preserved so gap detection continues correctly
  /// across the brief subscription gap during the stream restart.
  void _switchToStationaryMode() {
    _streamSub?.cancel();
    _stationaryMode = true;
    _stationaryCounter = 0;
    _streamSub =
        LocationService.trackPositionStationary().listen(_onRecordingFix);
    debugPrint('GPS: switched to stationary mode (low-frequency recording)');
  }

  /// Switches the recording stream back to high-frequency moving mode.
  ///
  /// Called on the first accepted fix that exceeds [kStationarySpeedThreshold]
  /// after a stationary period.
  void _switchToMovingMode() {
    _streamSub?.cancel();
    _stationaryMode = false;
    _stationaryCounter = 0;
    _streamSub = LocationService.trackPosition().listen(_onRecordingFix);
    debugPrint('GPS: switched to moving mode (high-frequency recording)');
  }

  /// Shared handler for every GPS fix during recording, regardless of stream
  /// mode (high-frequency moving or low-frequency stationary).
  ///
  /// Applies:
  /// 1. Ambient field updates ([_updateFromPosition]).
  /// 2. The horizontal accuracy gate and adaptive buffer.
  /// 3. The heading-change diagnostic log (debug builds only).
  /// 4. The stationary detection state machine.
  /// 5. Fix acceptance via [_acceptFix].
  void _onRecordingFix(Position pos) {
    _updateFromPosition(pos);
    final now = DateTime.now();

    if (pos.accuracy <= kMaxAcceptableAccuracyMetres) {
      // Good fix — commit any buffered fix first.
      if (_accuracyBuffer.isNotEmpty) {
        final best = _accuracyBuffer.reduce(
          (a, b) => a.accuracy <= b.accuracy ? a : b,
        );
        _accuracyBuffer.clear();
        _bufferStartedAt = null;
        _acceptFix(best.lat, best.lon, best.heading, best.receivedAt);
      }
      _consecutiveDropped = 0;

      // Heading-change gate — reduces accepted fixes on straight trail sections,
      // saving battery in release builds. This guard runs unconditionally in
      // both debug and release; wrapping it in assert() would make it a no-op
      // in production (assert blocks are stripped by the Dart compiler).
      //
      // Gate logic: when the hiker is moving AND the heading has not changed by
      // at least kHeadingChangeDegrees since the last accepted fix, skip this
      // fix. Stationary fixes (speed below kMinSpeedForHeadingTrigger) are
      // always accepted so rest-stop timestamps are recorded accurately.
      //
      // Feature: GPS accuracy field validation (R1).
      // If speedAccuracy is reported (> 0), use the lower bound of the speed
      // estimate so the gate does not fire when the chipset is too uncertain
      // about speed to distinguish movement from noise.
      {
        final bool isMoving;
        if (pos.speedAccuracy > 0.0) {
          isMoving = (pos.speed - pos.speedAccuracy) >= kMinSpeedForHeadingTrigger;
        } else {
          isMoving = pos.speed >= kMinSpeedForHeadingTrigger;
        }
        final delta = _headingDelta(pos.heading, _lastRecordedHeading);
        // Log heading-change triggers in debug builds for diagnostics.
        assert(() {
          if (isMoving && delta >= kHeadingChangeDegrees) {
            final saStr = pos.speedAccuracy > 0.0
                ? ' (speedAcc: ${pos.speedAccuracy.toStringAsFixed(2)} m/s)'
                : '';
            debugPrint(
              'GPS heading change: ${delta.toStringAsFixed(1)}° '
              'at ${pos.speed.toStringAsFixed(2)} m/s$saStr',
            );
          }
          return true;
        }());
        // Skip the fix when moving in a straight line (below heading threshold).
        // Always accept the first fix of a session (_lastRecordedHeading is null
        // so delta is 0 — we must not gate out the session-start fix).
        // Note: _updateFromPosition() has already been called unconditionally at
        // the top of _onRecordingFix, so ambient fields remain current even when
        // returning early here.
        if (_lastRecordedHeading != null &&
            isMoving &&
            delta < kHeadingChangeDegrees) {
          return;
        }
      }

      // Stationary detection state machine.
      if (pos.speed < kStationarySpeedThreshold) {
        _stationaryCounter++;
        // Debounce: require kStationaryDebounceSecs of continuous low speed.
        const threshold =
            kStationaryDebounceSecs ~/ kRecordingTimeIntervalSeconds;
        if (_stationaryCounter >= threshold && !_stationaryMode) {
          _acceptFix(pos.latitude, pos.longitude, pos.heading, now);
          _switchToStationaryMode();
          return;
        }
      } else {
        _stationaryCounter = 0;
        if (_stationaryMode) {
          // Hiker is moving again — accept this fix then switch back.
          _acceptFix(pos.latitude, pos.longitude, pos.heading, now);
          _switchToMovingMode();
          return;
        }
      }

      _acceptFix(pos.latitude, pos.longitude, pos.heading, now);
    } else {
      // Poor fix — add to adaptive buffer.
      _consecutiveDropped++;
      if (_consecutiveDropped == _kConsecutiveDropThreshold) {
        debugPrint(
          'GPS quality warning: $_kConsecutiveDropThreshold consecutive '
          'fixes exceeded accuracy threshold. Last accuracy: '
          '${pos.accuracy.toStringAsFixed(1)} m. '
          'Recording paused until signal improves.',
        );
        _consecutiveDropped = 0;
      }

      _bufferStartedAt ??= now;

      if (_accuracyBuffer.length < kAdaptiveBufferMaxFixes) {
        _accuracyBuffer.add(_BufferedFix(
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          heading: pos.heading,
          receivedAt: now,
        ));
      } else {
        // Replace the worst fix to keep buffer bounded.
        int worstIdx = 0;
        for (var i = 1; i < _accuracyBuffer.length; i++) {
          if (_accuracyBuffer[i].accuracy >
              _accuracyBuffer[worstIdx].accuracy) {
            worstIdx = i;
          }
        }
        if (pos.accuracy < _accuracyBuffer[worstIdx].accuracy) {
          _accuracyBuffer[worstIdx] = _BufferedFix(
            lat: pos.latitude,
            lon: pos.longitude,
            accuracy: pos.accuracy,
            heading: pos.heading,
            receivedAt: now,
          );
        }
      }

      // Buffer timeout — flush and insert gap marker.
      final bufferAge = now.difference(_bufferStartedAt!).inSeconds;
      if (bufferAge >= kAdaptiveBufferWindowSeconds) {
        _accuracyBuffer.clear();
        _bufferStartedAt = null;
        _insertGapMarker();
        _lastAcceptedFixAt = null;
      }

      notifyListeners();
    }
  }

  /// Updates all ambient fields from a raw [Position] event.
  ///
  /// Altitude is smoothed with an exponential moving average to reduce
  /// +-10-30 m jitter typical of consumer GPS chipsets.
  ///
  /// Feature: GPS accuracy field validation (R2, R3).
  /// If [Position.altitudeAccuracy] is reported (> 0) and exceeds
  /// [kMaxAcceptableAccuracyMetres], the EMA update is skipped — the
  /// previous smoothed altitude is preserved rather than being shifted by
  /// a low-quality reading. When altitudeAccuracy is 0.0 (unavailable on
  /// older devices), the EMA is applied unconditionally as before.
  void _updateFromPosition(Position pos) {
    _ambientPosition = LatLng(pos.latitude, pos.longitude);
    _ambientHeading = pos.heading;

    // Altitude accuracy gate (R2).
    final bool altitudeIsReliable =
        pos.altitudeAccuracy == 0.0 || // unavailable → assume good
        pos.altitudeAccuracy <= kMaxAcceptableAccuracyMetres;

    if (altitudeIsReliable) {
      _ambientAltitude = _ambientAltitude == 0.0
          ? pos.altitude
          : _ambientAltitude * (1 - _kAltitudeEmaAlpha) +
              pos.altitude * _kAltitudeEmaAlpha;
    } else {
      // Log poor altitude fix in debug builds (R3).
      assert(() {
        debugPrint(
          'GPS altitude skipped: altitudeAccuracy '
          '${pos.altitudeAccuracy.toStringAsFixed(1)} m exceeds threshold '
          '${kMaxAcceptableAccuracyMetres.toStringAsFixed(0)} m — '
          'EMA unchanged at ${_ambientAltitude.toStringAsFixed(1)} m',
        );
        return true;
      }());
    }

    // Log non-zero accuracy fields in debug builds (R3).
    assert(() {
      if (pos.speedAccuracy > 0.0 || pos.altitudeAccuracy > 0.0) {
        debugPrint(
          'GPS accuracy fields — '
          'horiz: ${pos.accuracy.toStringAsFixed(1)} m  '
          'speed: ${pos.speedAccuracy.toStringAsFixed(2)} m/s  '
          'alt: ${pos.altitudeAccuracy.toStringAsFixed(1)} m',
        );
      }
      return true;
    }());

    _ambientSpeed = pos.speed;
    _lastAccuracy = pos.accuracy;
  }
}
