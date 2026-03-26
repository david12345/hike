import 'package:pedometer/pedometer.dart';

/// Static wrapper around the `pedometer` plugin.
///
/// Follows the same static-service pattern as [CompassService] and
/// [WeatherService]. Exposes a stream of cumulative step counts from
/// the device hardware step-counter sensor.
class PedometerService {
  PedometerService._();

  /// Stream of cumulative step counts from the device sensor.
  ///
  /// Each event is the total step count since the device was last rebooted.
  /// Callers must capture a baseline and compute the delta themselves.
  /// Maps [StepCount] events to plain [int] values.
  static Stream<int> get stepCountStream =>
      Pedometer.stepCountStream.map((event) => event.steps);
}
