import 'package:latlong2/latlong.dart';

/// Default map centre used when no GPS fix is available.
/// Corresponds to Coimbra, Portugal.
const kFallbackLocation = LatLng(40.2033, -8.4103);

/// Package identifier used as the OSM tile `userAgentPackageName`.
/// Must match the `applicationId` in `android/app/build.gradle.kts`.
const kPackageName = 'com.dealmeida.hike';

/// Android foreground service notification ID used by [ForegroundTrackingService].
///
/// Must be a positive integer unique within the app's notification namespace.
/// Value 256 is chosen to avoid collision with system-reserved IDs.
const kForegroundServiceId = 256;
