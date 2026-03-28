import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final DateTime receivedAt;

  const _BufferedFix({
    required this.lat,
    required this.lon,
    required this.accuracy,
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
class TrackingState extends ChangeNotifier {
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

  /// Wall time when the first buffered fix was received.
  DateTime? _bufferStartedAt;

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
    _startAmbientStream();
    notifyListeners();
  }

  /// Cancels the active GPS subscription and closes the recording point
  /// stream controller.
  ///
  /// Called from [_HomePageState.dispose] on app exit to release the
  /// platform GPS stream cleanly.
  void cancelStream() {
    _streamSub?.cancel();
    _streamSub = null;
    _recordingPointController.close();
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
  void _acceptFix(double lat, double lon, DateTime now) {
    if (!_gapJustInserted && _lastAcceptedFixAt != null) {
      final gapSeconds = now.difference(_lastAcceptedFixAt!).inSeconds;
      if (gapSeconds >= kGapThresholdSeconds) {
        _insertGapMarker();
      }
    }
    _lastAcceptedFixAt = now;
    if (!_recordingPointController.isClosed) {
      _recordingPointController.add((lat: lat, lon: lon));
    }
    addPoint(lat, lon);
  }

  /// Starts the high-accuracy recording GPS stream.
  ///
  /// Fixes with [Position.accuracy] > [kMaxAcceptableAccuracyMetres] are
  /// held in a short adaptive buffer waiting for recovery. If signal recovers
  /// within [kAdaptiveBufferWindowSeconds], the best buffered fix is committed
  /// before the new good fix. If not, the buffer is flushed and a gap marker
  /// is inserted.
  void _startRecordingStream() {
    _streamSub?.cancel();
    _consecutiveDropped = 0;
    _streamSub = LocationService.trackPosition().listen(
      (pos) {
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
            _acceptFix(best.lat, best.lon, best.receivedAt);
          }
          _consecutiveDropped = 0;
          _acceptFix(pos.latitude, pos.longitude, now);
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
                receivedAt: now,
              );
            }
          }

          // Buffer timeout — flush and insert gap marker.
          final bufferAge =
              now.difference(_bufferStartedAt!).inSeconds;
          if (bufferAge >= kAdaptiveBufferWindowSeconds) {
            _accuracyBuffer.clear();
            _bufferStartedAt = null;
            _insertGapMarker();
            _lastAcceptedFixAt = null;
          }

          notifyListeners();
        }
      },
    );
  }

  /// Updates all ambient fields from a raw [Position] event.
  ///
  /// Altitude is smoothed with an exponential moving average to reduce
  /// +-10-30 m jitter typical of consumer GPS chipsets.
  void _updateFromPosition(Position pos) {
    _ambientPosition = LatLng(pos.latitude, pos.longitude);
    _ambientHeading = pos.heading;
    _ambientAltitude = _ambientAltitude == 0.0
        ? pos.altitude
        : _ambientAltitude * (1 - _kAltitudeEmaAlpha) +
            pos.altitude * _kAltitudeEmaAlpha;
    _ambientSpeed = pos.speed;
    _lastAccuracy = pos.accuracy;
  }
}
