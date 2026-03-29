import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hike/utils/path_simplifier.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper builders
  // ---------------------------------------------------------------------------

  /// Builds a straight horizontal line of [n] evenly spaced points at
  /// latitude 40.0, longitude increasing by 0.001° per step.
  ({List<double> lats, List<double> lons}) straightLine(int n) {
    final lats = List<double>.generate(n, (_) => 40.0);
    final lons = List<double>.generate(n, (i) => i * 0.001);
    return (lats: lats, lons: lons);
  }

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('edge cases', () {
    test('empty list → empty output', () {
      final result = simplifyHikeRecord([], []);
      expect(result.latitudes, isEmpty);
      expect(result.longitudes, isEmpty);
    });

    test('single point → returned unchanged', () {
      final result = simplifyHikeRecord([40.0], [-8.0]);
      expect(result.latitudes, equals([40.0]));
      expect(result.longitudes, equals([-8.0]));
    });

    test('two points → both returned unchanged', () {
      final result = simplifyHikeRecord([40.0, 40.1], [-8.0, -8.1]);
      expect(result.latitudes, equals([40.0, 40.1]));
      expect(result.longitudes, equals([-8.0, -8.1]));
    });
  });

  // ---------------------------------------------------------------------------
  // Straight-line reduction
  // ---------------------------------------------------------------------------

  group('straight-line reduction', () {
    test('20 collinear points → 2 points (start + end) at epsilon = 1 m', () {
      final line = straightLine(20);
      final result = simplifyHikeRecord(line.lats, line.lons, epsilon: 1.0);
      expect(result.latitudes.length, equals(2));
      expect(result.latitudes.first, closeTo(line.lats.first, 1e-9));
      expect(result.latitudes.last, closeTo(line.lats.last, 1e-9));
      expect(result.longitudes.first, closeTo(line.lons.first, 1e-9));
      expect(result.longitudes.last, closeTo(line.lons.last, 1e-9));
    });

    test('5 collinear points → 2 points at large epsilon', () {
      final line = straightLine(5);
      final result = simplifyHikeRecord(line.lats, line.lons, epsilon: 1000.0);
      expect(result.latitudes.length, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // Right-angle turn
  // ---------------------------------------------------------------------------

  group('right-angle turn', () {
    test('midpoint at 90° bend is preserved when deviation >> epsilon', () {
      // Start (0,0) → Mid (0.1,0) → End (0.1,0.1).
      // Perpendicular deviation of Mid from the Start→End chord is ~7.8 km,
      // far above any reasonable epsilon.
      final lats = [0.0, 0.1, 0.1];
      final lons = [0.0, 0.0, 0.1];
      final result = simplifyHikeRecord(lats, lons, epsilon: 3.0);
      expect(result.latitudes.length, equals(3));
    });

    test('first and last point always present after simplification', () {
      final line = straightLine(10);
      final result = simplifyHikeRecord(line.lats, line.lons, epsilon: 1.0);
      expect(result.latitudes.first, closeTo(line.lats.first, 1e-9));
      expect(result.latitudes.last, closeTo(line.lats.last, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // NaN sentinel handling
  // ---------------------------------------------------------------------------

  group('NaN sentinel handling', () {
    test('single gap marker in the middle is preserved', () {
      final seg = straightLine(20);
      final lats = [...seg.lats, double.nan, ...seg.lats];
      final lons = [...seg.lons, double.nan, ...seg.lons];

      final result = simplifyHikeRecord(lats, lons, epsilon: 1.0);

      final nanCount = result.latitudes.where((v) => v.isNaN).length;
      expect(nanCount, equals(1),
          reason: 'exactly one gap marker must be in output');

      // Each non-NaN segment must have at least 2 points.
      for (final segment in _splitAtNan(result.latitudes)) {
        expect(segment.length, greaterThanOrEqualTo(2));
      }
    });

    test('first and last real point of each segment are preserved', () {
      final seg = straightLine(10);
      final lats = [...seg.lats, double.nan, ...seg.lats];
      final lons = [...seg.lons, double.nan, ...seg.lons];

      final result = simplifyHikeRecord(lats, lons, epsilon: 1.0);
      for (final segment in _splitAtNan(result.latitudes)) {
        expect(segment.first, closeTo(seg.lats.first, 1e-9));
        expect(segment.last, closeTo(seg.lats.last, 1e-9));
      }
    });

    test('two consecutive gap markers are both preserved', () {
      final seg = straightLine(5);
      final lats = [...seg.lats, double.nan, double.nan, ...seg.lats];
      final lons = [...seg.lons, double.nan, double.nan, ...seg.lons];

      final result = simplifyHikeRecord(lats, lons, epsilon: 1.0);
      final nanCount = result.latitudes.where((v) => v.isNaN).length;
      expect(nanCount, equals(2));
    });

    test('trailing NaN sentinel is preserved', () {
      final line = straightLine(5);
      final lats = [...line.lats, double.nan];
      final lons = [...line.lons, double.nan];

      final result = simplifyHikeRecord(lats, lons, epsilon: 1.0);
      expect(result.latitudes.last.isNaN, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Epsilon sensitivity
  // ---------------------------------------------------------------------------

  group('epsilon sensitivity', () {
    test('small epsilon keeps more points than large epsilon on a curved path',
        () {
      // Build 21 points on a quarter-circle arc (enough curve to have
      // measurable perpendicular deviations at realistic GPS scales).
      final lats = <double>[];
      final lons = <double>[];
      for (var i = 0; i <= 20; i++) {
        final angle = i * (math.pi / 2) / 20;
        lats.add(40.0 + 0.05 * (1 - math.cos(angle)));
        lons.add(-8.0 + 0.05 * math.sin(angle));
      }

      final aggressive = simplifyHikeRecord(lats, lons, epsilon: 500.0);
      final gentle = simplifyHikeRecord(lats, lons, epsilon: 1.0);

      expect(gentle.latitudes.length,
          greaterThan(aggressive.latitudes.length),
          reason: 'small epsilon retains more points');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Splits [values] into sublists at NaN boundaries (NaN entries excluded).
List<List<double>> _splitAtNan(List<double> values) {
  final result = <List<double>>[];
  var current = <double>[];
  for (final v in values) {
    if (v.isNaN) {
      if (current.isNotEmpty) result.add(current);
      current = [];
    } else {
      current.add(v);
    }
  }
  if (current.isNotEmpty) result.add(current);
  return result;
}
