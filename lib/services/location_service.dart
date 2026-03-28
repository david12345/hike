import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  static Future<Position?> getCurrentPosition() async {
    final ok = await requestPermission();
    if (!ok) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Stream<Position> trackPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    );
  }

  /// Returns a low-power GPS stream suitable for ambient (non-recording) use.
  ///
  /// Uses network-assisted positioning (`LocationAccuracy.medium`) with a
  /// 50-metre distance filter to minimise battery consumption while still
  /// keeping the map dot and coordinate tiles reasonably up-to-date.
  static Stream<Position> trackPositionAmbient() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50,
      ),
    );
  }

  /// Request background location permission (Android 10+).
  /// Must be called AFTER foreground location permission is granted.
  static Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status == PermissionStatus.granted;
  }

  static double distanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
