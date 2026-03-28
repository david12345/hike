import 'package:latlong2/latlong.dart';

/// Default map centre used when no GPS fix is available.
/// Corresponds to Coimbra, Portugal.
const kFallbackLocation = LatLng(40.2033, -8.4103);

/// Package identifier used as the OSM tile `userAgentPackageName`.
/// Must match the `applicationId` in `android/app/build.gradle.kts`.
const kPackageName = 'com.dealmeida.hike';

/// Maximum horizontal accuracy radius (metres) a GPS fix must satisfy to be
/// accepted into the recorded route.
///
/// Fixes with [Position.accuracy] > this threshold are silently dropped.
/// A value of 30 m admits the worst real GPS fixes (in-pocket, body-blocked)
/// and rejects all cell-only fallback positions (typically 50–500 m).
const kMaxAcceptableAccuracyMetres = 30.0;

/// Minimum displacement (metres) between accepted GPS fixes during recording.
///
/// Reduced from 5 m to 3 m to capture tighter switchbacks more faithfully.
const kRecordingDistanceFilterMetres = 3;

/// Minimum time between GPS fixes during recording (Android only).
///
/// Guarantees a fix is delivered at least every 5 seconds even when the
/// hiker is stationary or moving very slowly (< 3 m in 5 s = < 2.2 km/h).
const kRecordingTimeIntervalSeconds = 5;

/// Minimum elapsed time (seconds) with no accepted GPS fix before a gap
/// marker is inserted into the recorded route.
///
/// 30 seconds covers brief pocket signal loss while avoiding false gaps on
/// normal winding-trail recording.
const kGapThresholdSeconds = 30;

/// Duration (seconds) the adaptive buffer holds poor-quality GPS fixes
/// waiting for signal recovery before flushing and inserting a gap marker.
///
/// 15 seconds is long enough to span most momentary pocket rotations (8–12 s)
/// while short enough that a genuine blackout produces a gap marker before
/// the hiker has moved far from the last known position.
const kAdaptiveBufferWindowSeconds = 15;

/// Maximum number of poor-quality fixes to hold in the adaptive buffer.
///
/// A cap prevents unbounded memory growth if fixes arrive rapidly during a
/// long degradation window. The best fix (lowest accuracy) is always kept.
const kAdaptiveBufferMaxFixes = 10;

/// Android foreground service notification ID used by [ForegroundTrackingService].
///
/// Must be a positive integer unique within the app's notification namespace.
/// Value 256 is chosen to avoid collision with system-reserved IDs.
const kForegroundServiceId = 256;
