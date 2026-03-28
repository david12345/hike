import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
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

const double _earthRadiusKm = 6371.0;

double _toRad(double deg) => deg * pi / 180.0;

double _haversineDistanceKm(
    double lat1, double lon1, double lat2, double lon2) {
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) *
          sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return _earthRadiusKm * c;
}

/// Computes total distance in kilometres by summing haversine distances
/// between consecutive points defined by [latitudes] and [longitudes].
double computeDistanceKm(List<double> latitudes, List<double> longitudes) {
  var totalKm = 0.0;
  for (var i = 0; i < latitudes.length - 1; i++) {
    totalKm += _haversineDistanceKm(
      latitudes[i], longitudes[i],
      latitudes[i + 1], longitudes[i + 1],
    );
  }
  return totalKm;
}

/// Removes the file extension from [filename] (e.g. "trail.gpx" -> "trail").
String stripExtension(String filename) {
  final dotIndex = filename.lastIndexOf('.');
  return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
}
