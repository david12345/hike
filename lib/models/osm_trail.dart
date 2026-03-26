import 'package:latlong2/latlong.dart';

/// A hiking trail fetched from the Overpass API (OpenStreetMap).
///
/// Instances are ephemeral -- fetched on demand, not persisted locally.
/// The [geometry] list always contains at least 2 points.
class OsmTrail {
  /// The OpenStreetMap relation ID.
  final int osmId;

  /// Trail name from the `name` tag, or `'Unnamed Trail'` if missing.
  final String name;

  /// Trail distance in kilometres. Parsed from the `distance` tag or
  /// computed from the geometry via haversine summation.
  final double distanceKm;

  /// Human-readable difficulty: `'Easy'`, `'Moderate'`, `'Hard'`, or `'Unknown'`.
  final String difficulty;

  /// Optional description from the `description` tag.
  final String description;

  /// Ordered list of coordinates forming the trail route (>= 2 points).
  final List<LatLng> geometry;

  /// Network scope level: `'Local'`, `'Regional'`, `'National'`,
  /// `'International'`, or `'Unknown'`.
  final String network;

  /// Trail operator name from the `operator` tag, or empty string if missing.
  final String operatorName;

  /// Trail reference code from the `ref` tag, or empty string if missing.
  final String ref;

  const OsmTrail({
    required this.osmId,
    required this.name,
    required this.distanceKm,
    required this.difficulty,
    required this.description,
    required this.geometry,
    this.network = 'Unknown',
    this.operatorName = '',
    this.ref = '',
  });
}
