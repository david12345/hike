import 'package:flutter_compass/flutter_compass.dart';

/// Static service wrapping `flutter_compass` for magnetometer heading data.
///
/// Provides a heading stream and a utility to convert degrees to cardinal
/// direction strings using an 8-point compass.
class CompassService {
  /// Returns a stream of [CompassEvent]s, or `null` if the device has no
  /// magnetometer sensor.
  static Stream<CompassEvent>? get headingStream => FlutterCompass.events;

  /// Converts a heading in degrees (0-360) to one of eight cardinal
  /// direction strings: N, NE, E, SE, S, SW, W, NW.
  ///
  /// Uses 45-degree sectors centered on each direction.
  static String headingToCardinal(double heading) {
    // Normalize heading to 0-360 range.
    final h = heading % 360;
    if (h >= 337.5 || h < 22.5) return 'N';
    if (h < 67.5) return 'NE';
    if (h < 112.5) return 'E';
    if (h < 157.5) return 'SE';
    if (h < 202.5) return 'S';
    if (h < 247.5) return 'SW';
    if (h < 292.5) return 'W';
    return 'NW';
  }
}
