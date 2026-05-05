import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Primary brand colour used in the theme seed and analytics charts.
///
/// Material green 800. Defined here so a colour change requires editing
/// exactly one file.
const kBrandGreen = Color(0xFF2E7D32);

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

/// Maximum acceptable speed accuracy (metres per second) before the chipset's
/// speed reading is considered too uncertain to update the displayed value.
///
/// `Position.speedAccuracy` reports the chipset's own uncertainty estimate
/// (Android API >= 26). A reading of `pos.speed = 0.8 m/s` with
/// `pos.speedAccuracy = 1.5 m/s` means the true speed is somewhere between 0
/// and 2.3 m/s — too uncertain to display. 1.0 m/s (~3.6 km/h) is a tight
/// enough bound that surviving readings are within ±0.5 km/h of the true pace
/// at walking speeds.
const kMaxAcceptableSpeedAccuracyMps = 1.0;

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

// ---------------------------------------------------------------------------
// Smart stationary detection
// ---------------------------------------------------------------------------

/// Speed threshold (m/s) below which the hiker is considered stationary.
///
/// 0.5 m/s (1.8 km/h) is a deliberate walk; below this the hiker is
/// stopping or shuffling. At 0.5 m/s the heading reading is also
/// unreliable, so this threshold matches the conditions where dense
/// GPS sampling has no fidelity benefit.
const kStationarySpeedThreshold = 0.5;

/// Elapsed seconds of sub-threshold speed before the recording stream
/// switches to stationary (low-frequency) mode.
///
/// 10 seconds prevents mode-switching during momentary pauses (tying a
/// lace, looking at the phone) while being short enough to avoid capturing
/// many unnecessary fixes before the switch takes effect.
const kStationaryDebounceSecs = 10;

/// Distance filter (metres) used in stationary recording mode.
///
/// 10 m means the platform delivers a fix only if the device has genuinely
/// moved 10 m — effectively suppressing jitter and chipset wake-ups
/// during a rest stop.
const kStationaryDistanceFilterMetres = 10;

/// Time interval (seconds) used in stationary recording mode (Android only).
///
/// 10 seconds is a low-power rate that still captures the moment the hiker
/// resumes walking (first fix within 10 s of movement).
const kStationaryTimeIntervalSeconds = 10;

// ---------------------------------------------------------------------------
// Stationary drift filter
// ---------------------------------------------------------------------------

/// Number of consecutive GPS fixes that must all fall within
/// [kDriftFilterRadiusMetres] of each other before the hiker is considered
/// stationary for drift-filtering purposes.
///
/// 3 fixes at 2 s intervals = 6 seconds of stationary evidence.
const int kDriftFilterWindowSize = 3;

/// Radius (metres) within which consecutive fixes are treated as stationary
/// jitter rather than genuine movement.
///
/// 8 m covers GPS jitter at moderate-sky locations (partial canopy, urban
/// canyons) while remaining well below the 30 m accuracy gate threshold.
const double kDriftFilterRadiusMetres = 8.0;
