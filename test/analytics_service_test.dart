import 'package:flutter_test/flutter_test.dart';
import 'package:hike/models/hike_record.dart';
import 'package:hike/services/analytics_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [HikeRecord] with the given [startTime] and [distanceMeters].
/// All other fields take sensible defaults.
HikeRecord _hike({
  required DateTime startTime,
  double distanceMeters = 5000,
  Duration duration = const Duration(hours: 1),
  int steps = 0,
}) {
  return HikeRecord(
    id: 'test-${startTime.toIso8601String()}',
    name: 'Test Hike',
    startTime: startTime,
    endTime: startTime.add(duration),
    distanceMeters: distanceMeters,
    steps: steps,
  );
}

// A fixed reference date (a Tuesday) used throughout the tests.
final _base = DateTime(2024, 6, 11); // Tuesday 11 June 2024

void main() {
  group('AnalyticsService.compute – empty list', () {
    test('returns zero totals without throwing', () {
      final stats = AnalyticsService.compute([], []);
      expect(stats.totalHikes, equals(0));
      expect(stats.totalDistanceKm, equals(0.0));
      expect(stats.totalDuration, equals(Duration.zero));
      expect(stats.totalSteps, equals(0));
      expect(stats.avgDistanceKm, equals(0.0));
      expect(stats.avgDuration, equals(Duration.zero));
      expect(stats.avgPaceMinPerKm, equals(0.0));
    });

    test('personal bests are null', () {
      final stats = AnalyticsService.compute([], []);
      expect(stats.longestByDistance, isNull);
      expect(stats.longestByDuration, isNull);
      expect(stats.bestPace, isNull);
      expect(stats.mostSteps, isNull);
    });

    test('streaks are zero', () {
      final stats = AnalyticsService.compute([], []);
      expect(stats.currentStreak, equals(0));
      expect(stats.longestStreak, equals(0));
    });

    test('buckets are empty or zeroed', () {
      final stats = AnalyticsService.compute([], []);
      expect(stats.monthlyDistance, isEmpty);
      expect(stats.dayOfWeekCounts, equals([0, 0, 0, 0, 0, 0, 0]));
      expect(stats.distanceBuckets, equals([0, 0, 0, 0, 0]));
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – single hike', () {
    late HikeRecord hike;
    late AnalyticsStats stats;

    setUp(() {
      hike = _hike(
        startTime: _base,
        distanceMeters: 8000,
        duration: const Duration(hours: 2),
        steps: 9000,
      );
      stats = AnalyticsService.compute([hike], [hike]);
    });

    test('totals are correct', () {
      expect(stats.totalHikes, equals(1));
      expect(stats.totalDistanceKm, closeTo(8.0, 1e-9));
      expect(stats.totalDuration, equals(const Duration(hours: 2)));
      expect(stats.totalSteps, equals(9000));
    });

    test('averages equal totals for single hike', () {
      expect(stats.avgDistanceKm, closeTo(8.0, 1e-9));
      expect(stats.avgDuration, equals(const Duration(hours: 2)));
    });

    test('personal bests point to the only hike', () {
      expect(stats.longestByDistance, same(hike));
      expect(stats.longestByDuration, same(hike));
      expect(stats.mostSteps, same(hike));
    });

    test('bestPace is set (distance >= 500 m)', () {
      expect(stats.bestPace, same(hike));
    });

    test('longest streak is 1 (one unique day)', () {
      expect(stats.longestStreak, equals(1));
    });

    test('monthly distance has one bucket', () {
      expect(stats.monthlyDistance.length, equals(1));
      expect(stats.monthlyDistance.first.distanceKm, closeTo(8.0, 1e-9));
      expect(stats.monthlyDistance.first.year, equals(2024));
      expect(stats.monthlyDistance.first.month, equals(6));
    });

    test('day-of-week count incremented for Tuesday (index 1)', () {
      // _base is a Tuesday → weekday 2 → index 1.
      expect(stats.dayOfWeekCounts[1], equals(1));
      // All other days are 0.
      for (var i = 0; i < 7; i++) {
        if (i != 1) expect(stats.dayOfWeekCounts[i], equals(0));
      }
    });

    test('distance bucket: 8 km falls in 5–10 km bucket (index 2)', () {
      expect(stats.distanceBuckets[2], equals(1));
      for (var i = 0; i < 5; i++) {
        if (i != 2) expect(stats.distanceBuckets[i], equals(0));
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – multiple hikes, totals', () {
    test('distance and duration sum correctly across hikes', () {
      final hikes = [
        _hike(startTime: _base, distanceMeters: 3000,
            duration: const Duration(minutes: 30)),
        _hike(startTime: _base.add(const Duration(days: 1)),
            distanceMeters: 7000, duration: const Duration(hours: 1)),
        _hike(startTime: _base.add(const Duration(days: 2)),
            distanceMeters: 15000, duration: const Duration(hours: 3)),
      ];

      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.totalHikes, equals(3));
      expect(stats.totalDistanceKm, closeTo(25.0, 1e-9));
      expect(stats.totalDuration, equals(const Duration(hours: 4, minutes: 30)));
    });

    test('longestByDistance picks the right record', () {
      final short = _hike(startTime: _base, distanceMeters: 3000);
      final long = _hike(
          startTime: _base.add(const Duration(days: 1)),
          distanceMeters: 12000);
      final stats = AnalyticsService.compute([short, long], [short, long]);
      expect(stats.longestByDistance, same(long));
    });

    test('longestByDuration picks the right record', () {
      final fast = _hike(startTime: _base, distanceMeters: 5000,
          duration: const Duration(minutes: 30));
      final slow = _hike(
          startTime: _base.add(const Duration(days: 1)),
          distanceMeters: 5000,
          duration: const Duration(hours: 4));
      final stats = AnalyticsService.compute([fast, slow], [fast, slow]);
      expect(stats.longestByDuration, same(slow));
    });

    test('mostSteps is null when all hikes have 0 steps', () {
      final hikes = [
        _hike(startTime: _base, steps: 0),
        _hike(startTime: _base.add(const Duration(days: 1)), steps: 0),
      ];
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.mostSteps, isNull);
    });

    test('bestPace is null for hikes all under 500 m', () {
      final hikes = [
        _hike(startTime: _base, distanceMeters: 200),
        _hike(startTime: _base.add(const Duration(days: 1)),
            distanceMeters: 400),
      ];
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.bestPace, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – streak calculation', () {
    test('consecutive days have correct longest streak', () {
      final hikes = List<HikeRecord>.generate(
        5,
        (i) => _hike(startTime: _base.add(Duration(days: i))),
      );
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.longestStreak, equals(5));
    });

    test('gap in days resets streak', () {
      // Days 0, 1, 2 then gap, then days 4, 5.
      final hikes = [
        _hike(startTime: _base),
        _hike(startTime: _base.add(const Duration(days: 1))),
        _hike(startTime: _base.add(const Duration(days: 2))),
        // day 3 missing
        _hike(startTime: _base.add(const Duration(days: 4))),
        _hike(startTime: _base.add(const Duration(days: 5))),
      ];
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.longestStreak, equals(3));
    });

    test('multiple hikes on the same day count as one streak day', () {
      // Three hikes on the same day should count as streak length 1.
      final hikes = [
        _hike(startTime: _base),
        _hike(startTime: _base.add(const Duration(hours: 2))),
        _hike(startTime: _base.add(const Duration(hours: 4))),
      ];
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.longestStreak, equals(1));
    });

    test('current streak is > 0 when today has a hike', () {
      final todayHike = _hike(startTime: DateTime.now());
      final stats = AnalyticsService.compute([todayHike], [todayHike]);
      expect(stats.currentStreak, greaterThan(0));
    });

    test('current streak is 0 when no hike today (using old dates)', () {
      final hikes = [
        _hike(startTime: _base),
        _hike(startTime: _base.add(const Duration(days: 1))),
      ];
      // allHikes also uses old dates — today is not covered.
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.currentStreak, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – date range filter', () {
    test('filtered list excludes hikes outside range', () {
      final all = [
        _hike(startTime: _base, distanceMeters: 5000),
        _hike(
            startTime: _base.add(const Duration(days: 10)),
            distanceMeters: 8000),
        _hike(
            startTime: _base.add(const Duration(days: 20)),
            distanceMeters: 3000),
      ];

      // Filter to only the middle hike by passing just that one in [filtered].
      final filtered = [all[1]];
      final stats = AnalyticsService.compute(filtered, all);

      expect(stats.totalHikes, equals(1));
      expect(stats.totalDistanceKm, closeTo(8.0, 1e-9));
      // Streaks are computed on [allHikes], so longestStreak uses all 3 hikes.
      expect(stats.longestStreak, equals(1),
          reason: 'no consecutive days in the full dataset');
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – monthly bucket grouping', () {
    test('hikes in two different months produce two buckets', () {
      final june = _hike(
          startTime: DateTime(2024, 6, 15), distanceMeters: 5000);
      final july = _hike(
          startTime: DateTime(2024, 7, 1), distanceMeters: 7000);

      final stats = AnalyticsService.compute([june, july], [june, july]);

      expect(stats.monthlyDistance.length, equals(2));
      expect(stats.monthlyDistance[0].month, equals(6));
      expect(stats.monthlyDistance[0].distanceKm, closeTo(5.0, 1e-9));
      expect(stats.monthlyDistance[1].month, equals(7));
      expect(stats.monthlyDistance[1].distanceKm, closeTo(7.0, 1e-9));
    });

    test('hikes spanning year boundary produce correct months', () {
      final dec = _hike(
          startTime: DateTime(2023, 12, 28), distanceMeters: 4000);
      final jan = _hike(
          startTime: DateTime(2024, 1, 3), distanceMeters: 6000);

      final stats = AnalyticsService.compute([dec, jan], [dec, jan]);

      expect(stats.monthlyDistance.length, equals(2));
      expect(stats.monthlyDistance[0].year, equals(2023));
      expect(stats.monthlyDistance[0].month, equals(12));
      expect(stats.monthlyDistance[1].year, equals(2024));
      expect(stats.monthlyDistance[1].month, equals(1));
    });

    test('bucket shortLabel returns correct three-letter abbreviations', () {
      const bucket = MonthlyBucket(year: 2024, month: 3, distanceKm: 1.0);
      expect(bucket.shortLabel, equals('Mar'));
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – day-of-week distribution', () {
    test('Monday hike increments index 0', () {
      // Find the nearest Monday on or after _base.
      var monday = _base;
      while (monday.weekday != DateTime.monday) {
        monday = monday.add(const Duration(days: 1));
      }
      final hike = _hike(startTime: monday);
      final stats = AnalyticsService.compute([hike], [hike]);
      expect(stats.dayOfWeekCounts[0], equals(1));
    });

    test('Sunday hike increments index 6', () {
      var sunday = _base;
      while (sunday.weekday != DateTime.sunday) {
        sunday = sunday.add(const Duration(days: 1));
      }
      final hike = _hike(startTime: sunday);
      final stats = AnalyticsService.compute([hike], [hike]);
      expect(stats.dayOfWeekCounts[6], equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – distance distribution buckets', () {
    test('hike < 2 km → bucket 0', () {
      final h = _hike(startTime: _base, distanceMeters: 1500);
      final stats = AnalyticsService.compute([h], [h]);
      expect(stats.distanceBuckets[0], equals(1));
    });

    test('hike 2–5 km → bucket 1', () {
      final h = _hike(startTime: _base, distanceMeters: 3000);
      final stats = AnalyticsService.compute([h], [h]);
      expect(stats.distanceBuckets[1], equals(1));
    });

    test('hike 5–10 km → bucket 2', () {
      final h = _hike(startTime: _base, distanceMeters: 7000);
      final stats = AnalyticsService.compute([h], [h]);
      expect(stats.distanceBuckets[2], equals(1));
    });

    test('hike 10–20 km → bucket 3', () {
      final h = _hike(startTime: _base, distanceMeters: 15000);
      final stats = AnalyticsService.compute([h], [h]);
      expect(stats.distanceBuckets[3], equals(1));
    });

    test('hike >= 20 km → bucket 4', () {
      final h = _hike(startTime: _base, distanceMeters: 25000);
      final stats = AnalyticsService.compute([h], [h]);
      expect(stats.distanceBuckets[4], equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  group('AnalyticsService.compute – most hikes in one week', () {
    test('three hikes in the same ISO week', () {
      // Use Monday–Wednesday of the same week.
      var monday = _base;
      while (monday.weekday != DateTime.monday) {
        monday = monday.add(const Duration(days: 1));
      }
      final hikes = [
        _hike(startTime: monday),
        _hike(startTime: monday.add(const Duration(days: 1))),
        _hike(startTime: monday.add(const Duration(days: 2))),
      ];
      final stats = AnalyticsService.compute(hikes, hikes);
      expect(stats.mostHikesInOneWeek, equals(3));
    });
  });
}
