import 'dart:math';
import 'constants.dart';

/// Simplifies the GPS track stored in [latitudes] and [longitudes] using the
/// Douglas-Peucker algorithm, treating NaN entries as segment-boundary markers.
///
/// Each gap-delimited segment is simplified independently. Gap markers are
/// preserved in the output in their original relative positions.
///
/// [epsilon] is the maximum allowed perpendicular deviation in metres.
({List<double> latitudes, List<double> longitudes}) simplifyHikeRecord(
  List<double> latitudes,
  List<double> longitudes, {
  double epsilon = kPathSimplificationEpsilonMetres,
}) {
  assert(latitudes.length == longitudes.length);
  if (latitudes.length < 3) {
    return (
      latitudes: List<double>.from(latitudes),
      longitudes: List<double>.from(longitudes),
    );
  }

  final outLats = <double>[];
  final outLons = <double>[];

  var segStart = 0;
  for (var i = 0; i <= latitudes.length; i++) {
    final isEnd = i == latitudes.length;
    final isGap = !isEnd && latitudes[i].isNaN;
    if (isGap || isEnd) {
      final segLats = latitudes.sublist(segStart, i);
      final segLons = longitudes.sublist(segStart, i);
      final simplified = _simplifySegment(segLats, segLons, epsilon);
      outLats.addAll(simplified.latitudes);
      outLons.addAll(simplified.longitudes);
      if (isGap) {
        outLats.add(double.nan);
        outLons.add(double.nan);
        segStart = i + 1;
      }
    }
  }
  return (latitudes: outLats, longitudes: outLons);
}

({List<double> latitudes, List<double> longitudes}) _simplifySegment(
  List<double> lats,
  List<double> lons,
  double epsilon,
) {
  if (lats.length < 3) {
    return (
      latitudes: List<double>.from(lats),
      longitudes: List<double>.from(lons),
    );
  }

  final keep = List<bool>.filled(lats.length, false);
  keep[0] = true;
  keep[lats.length - 1] = true;

  // Pre-compute cos(lat) at segment midpoint for equirectangular projection.
  final midLat = (lats.first + lats.last) / 2.0;
  final cosLat = cos(midLat * pi / 180.0);

  _dpIterative(lats, lons, 0, lats.length - 1, epsilon, keep, cosLat);

  final outLats = <double>[];
  final outLons = <double>[];
  for (var i = 0; i < lats.length; i++) {
    if (keep[i]) {
      outLats.add(lats[i]);
      outLons.add(lons[i]);
    }
  }
  return (latitudes: outLats, longitudes: outLons);
}

void _dpIterative(
  List<double> lats,
  List<double> lons,
  int start,
  int end,
  double epsilon,
  List<bool> keep,
  double cosLat,
) {
  // Work stack: each entry is a (start, end) pair to process.
  final stack = <(int, int)>[(start, end)];

  while (stack.isNotEmpty) {
    final (s, e) = stack.removeLast();
    if (e <= s + 1) continue;

    double maxDist = 0.0;
    int pivot = s;

    for (var i = s + 1; i < e; i++) {
      final d = _perpendicularDistanceMetres(
        lats[i],
        lons[i],
        lats[s],
        lons[s],
        lats[e],
        lons[e],
        cosLat,
      );
      if (d > maxDist) {
        maxDist = d;
        pivot = i;
      }
    }

    if (maxDist > epsilon) {
      keep[pivot] = true;
      // Push both sub-segments; order does not affect correctness.
      stack.add((s, pivot));
      stack.add((pivot, e));
    }
  }
}

double _perpendicularDistanceMetres(
  double pLat,
  double pLon,
  double aLat,
  double aLon,
  double bLat,
  double bLon,
  double cosLat,
) {
  const metersPerDegLat = 111320.0;
  final metersPerDegLon = metersPerDegLat * cosLat;

  final px = pLon * metersPerDegLon;
  final py = pLat * metersPerDegLat;
  final ax = aLon * metersPerDegLon;
  final ay = aLat * metersPerDegLat;
  final bx = bLon * metersPerDegLon;
  final by = bLat * metersPerDegLat;

  final dx = bx - ax;
  final dy = by - ay;
  final lenSq = dx * dx + dy * dy;

  if (lenSq == 0.0) {
    // A and B are the same point; return distance from P to A.
    final ex = px - ax;
    final ey = py - ay;
    return sqrt(ex * ex + ey * ey);
  }

  final num = (dy * px - dx * py + bx * ay - by * ax).abs();
  return num / sqrt(lenSq);
}
