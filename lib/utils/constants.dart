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
/// Reduced from 3 m to 1 m to give the heading-change gate in
/// [TrackingState] enough raw fixes to detect tight bends. At normal hiking
/// pace (4 km/h = 1.1 m/s), 1 m displacement occurs every ~0.9 seconds,
/// keeping the fix rate close to the GPS chipset's 1 Hz output.
const kRecordingDistanceFilterMetres = 1;

/// Minimum time between GPS fixes during recording (Android only).
///
/// Reduced from 5 s to 2 s so that a roundabout traversed in ~9 s receives
/// 4–5 time-triggered fixes instead of 1–2, producing a visible arc rather
/// than straight chords. Battery impact is negligible: the GPS chipset
/// already runs at 1 Hz; only the Dart callback frequency changes.
const kRecordingTimeIntervalSeconds = 2;

/// Minimum heading change (degrees) since the last accepted GPS fix that
/// forces a new recording point regardless of distance travelled.
///
/// 10 degrees is large enough to ignore GPS heading noise on straight paths
/// (typical noise: 3–8 degrees) while small enough to capture a tight
/// switchback (radius 5 m ≈ 11 degrees per 1 m chord) with adequate density.
const kHeadingChangeDegrees = 10.0;

/// Minimum speed (m/s) required before the heading-change trigger is active.
///
/// Below this threshold the hiker is effectively stationary and GPS heading
/// readings are unreliable. 0.3 m/s ≈ 1 km/h.
const kMinSpeedForHeadingTrigger = 0.3;

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

/// Standard OpenStreetMap tile URL template.
const kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// OpenTopoMap tile URL template.
const kTopoTileUrl = 'https://tile.opentopomap.org/{z}/{x}/{y}.png';

/// Esri World Imagery satellite tile URL template.
/// Free for non-commercial use; no API key required.
/// Note: tile coordinate order is {z}/{y}/{x} (row/column), not {z}/{x}/{y}.
const kSatelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// Maximum perpendicular deviation (metres) used by the Douglas-Peucker
/// path simplifier. Points that deviate less than this from their neighbours'
/// chord are eliminated. 3 m preserves hiking-scale curves (switchback radius
/// >= 5 m) while removing GPS jitter noise.
const kPathSimplificationEpsilonMetres = 3.0;

/// Android foreground service notification ID used by [ForegroundTrackingService].
///
/// Must be a positive integer unique within the app's notification namespace.
/// Value 256 is chosen to avoid collision with system-reserved IDs.
const kForegroundServiceId = 256;
