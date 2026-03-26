import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Returns the smallest [LatLngBounds] that contains every point in [points].
///
/// Throws [ArgumentError] if [points] is empty. Callers must guard
/// against empty lists before invoking this function.
LatLngBounds boundsForPoints(List<LatLng> points) {
  if (points.isEmpty) {
    throw ArgumentError('points must not be empty');
  }

  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLon = points.first.longitude;
  double maxLon = points.first.longitude;

  for (final p in points) {
    minLat = min(minLat, p.latitude);
    maxLat = max(maxLat, p.latitude);
    minLon = min(minLon, p.longitude);
    maxLon = max(maxLon, p.longitude);
  }

  return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
}

/// Computes total distance in kilometres by summing haversine distances
/// between consecutive points defined by [latitudes] and [longitudes].
double computeDistanceKm(List<double> latitudes, List<double> longitudes) {
  var totalMeters = 0.0;
  for (var i = 0; i < latitudes.length - 1; i++) {
    totalMeters += Geolocator.distanceBetween(
      latitudes[i],
      longitudes[i],
      latitudes[i + 1],
      longitudes[i + 1],
    );
  }
  return totalMeters / 1000.0;
}

/// Removes the file extension from [filename] (e.g. "trail.gpx" -> "trail").
String stripExtension(String filename) {
  final dotIndex = filename.lastIndexOf('.');
  return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
}
