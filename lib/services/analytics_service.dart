/// Pure-Dart analytics computation. No Flutter or Hive dependencies.
///
/// Call [AnalyticsService.compute] with a filtered list of [HikeRecord]s and
/// the full unfiltered list to produce an [AnalyticsStats] value object.
library;

import '../models/hike_record.dart';

/// One calendar month bucket for the Distance by Month chart.
class MonthlyBucket {
  final int year;
  final int month; // 1–12
  final double distanceKm;

  const MonthlyBucket({
    required this.year,
    required this.month,
    required this.distanceKm,
  });

  /// E.g. "Jan", "Feb", …
  String get shortLabel {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month];
  }
}

/// Aggregated statistics derived from a set of [HikeRecord]s.
class AnalyticsStats {
  final int totalHikes;
  final double totalDistanceKm;
  final Duration totalDuration;
  final int totalSteps;
  final double avgDistanceKm;
  final Duration avgDuration;

  /// Average pace in minutes per km. 0 when [totalDistanceKm] is too small.
  final double avgPaceMinPerKm;

  final HikeRecord? longestByDistance;
  final HikeRecord? longestByDuration;

  /// Fastest (lowest min/km) hike with distanceMeters >= 500.
  final HikeRecord? bestPace;

  /// Hike with the most steps (null when no hike has steps > 0).
  final HikeRecord? mostSteps;

  /// Maximum number of hike records sharing the same ISO calendar week.
  final int mostHikesInOneWeek;

  // Streaks are computed over the full dataset, not just the filtered range.
  final int currentStreak;
  final int longestStreak;

  /// Monthly distance buckets covering the filtered range.
  final List<MonthlyBucket> monthlyDistance;

  /// Hike count per day of the week. Index 0 = Monday, index 6 = Sunday.
  final List<int> dayOfWeekCounts;

  /// Distance-distribution histogram: [0–2, 2–5, 5–10, 10–20, 20+] km buckets.
  final List<int> distanceBuckets;

  const AnalyticsStats({
    required this.totalHikes,
    required this.totalDistanceKm,
    required this.totalDuration,
    required this.totalSteps,
    required this.avgDistanceKm,
    required this.avgDuration,
    required this.avgPaceMinPerKm,
    required this.longestByDistance,
    required this.longestByDuration,
    required this.bestPace,
    required this.mostSteps,
    required this.mostHikesInOneWeek,
    required this.currentStreak,
    required this.longestStreak,
    required this.monthlyDistance,
    required this.dayOfWeekCounts,
    required this.distanceBuckets,
  });

  static const AnalyticsStats empty = AnalyticsStats(
    totalHikes: 0,
    totalDistanceKm: 0,
    totalDuration: Duration.zero,
    totalSteps: 0,
    avgDistanceKm: 0,
    avgDuration: Duration.zero,
    avgPaceMinPerKm: 0,
    longestByDistance: null,
    longestByDuration: null,
    bestPace: null,
    mostSteps: null,
    mostHikesInOneWeek: 0,
    currentStreak: 0,
    longestStreak: 0,
    monthlyDistance: [],
    dayOfWeekCounts: [0, 0, 0, 0, 0, 0, 0],
    distanceBuckets: [0, 0, 0, 0, 0],
  );
}

class AnalyticsService {
  AnalyticsService._();

  /// Compute analytics from [filtered] hikes (date-range scoped) and
  /// [allHikes] (full dataset, used only for streak computation).
  static AnalyticsStats compute(
    List<HikeRecord> filtered,
    List<HikeRecord> allHikes,
  ) {
    final int totalHikes = filtered.length;

    double totalDistanceKm = 0;
    int totalSeconds = 0;
    int totalSteps = 0;

    HikeRecord? longestByDistance;
    HikeRecord? longestByDuration;
    HikeRecord? bestPaceRecord;
    double bestPaceMinPerKm = double.infinity;
    HikeRecord? mostStepsRecord;
    int mostStepsValue = 0;

    for (final h in filtered) {
      final km = h.distanceMeters / 1000.0;
      totalDistanceKm += km;
      totalSeconds += h.duration.inSeconds;
      totalSteps += h.steps;

      if (longestByDistance == null ||
          h.distanceMeters > longestByDistance.distanceMeters) {
        longestByDistance = h;
      }
      if (longestByDuration == null ||
          h.duration > longestByDuration.duration) {
        longestByDuration = h;
      }
      if (h.distanceMeters >= 500) {
        final durationMin = h.duration.inSeconds / 60.0;
        final pace = km > 0 ? durationMin / km : double.infinity;
        if (pace < bestPaceMinPerKm) {
          bestPaceMinPerKm = pace;
          bestPaceRecord = h;
        }
      }
      if (h.steps > mostStepsValue) {
        mostStepsValue = h.steps;
        mostStepsRecord = h;
      }
    }

    final totalDuration = Duration(seconds: totalSeconds);
    final avgDistanceKm = totalHikes > 0 ? totalDistanceKm / totalHikes : 0.0;
    final avgDurationSeconds =
        totalHikes > 0 ? totalSeconds ~/ totalHikes : 0;
    final avgDuration = Duration(seconds: avgDurationSeconds);

    // Average pace: total minutes / total km. Exclude hikes < 50 m.
    double avgPaceMinPerKm = 0;
    {
      double paceDistKm = 0;
      int paceSeconds = 0;
      for (final h in filtered) {
        if (h.distanceMeters >= 50) {
          paceDistKm += h.distanceMeters / 1000.0;
          paceSeconds += h.duration.inSeconds;
        }
      }
      if (paceDistKm > 0) {
        avgPaceMinPerKm = (paceSeconds / 60.0) / paceDistKm;
      }
    }

    // Most hikes in a single ISO week.
    final weekCounts = <String, int>{};
    for (final h in filtered) {
      final key = _isoWeekKey(h.startTime);
      weekCounts[key] = (weekCounts[key] ?? 0) + 1;
    }
    final mostHikesInOneWeek =
        weekCounts.isEmpty ? 0 : weekCounts.values.reduce((a, b) => a > b ? a : b);

    // Streaks — computed on full dataset.
    final currentStreak = _currentStreak(allHikes);
    final longestStreak = _longestStreak(allHikes);

    // Monthly distance buckets.
    final monthlyDistance = _monthlyDistance(filtered);

    // Day-of-week counts (0=Mon, 6=Sun).
    final dayOfWeekCounts = List<int>.filled(7, 0);
    for (final h in filtered) {
      // weekday: 1=Mon … 7=Sun; convert to 0-based index.
      final idx = h.startTime.weekday - 1;
      dayOfWeekCounts[idx]++;
    }

    // Distance distribution buckets: 0-2, 2-5, 5-10, 10-20, 20+
    final distanceBuckets = List<int>.filled(5, 0);
    for (final h in filtered) {
      final km = h.distanceMeters / 1000.0;
      if (km < 2) {
        distanceBuckets[0]++;
      } else if (km < 5) {
        distanceBuckets[1]++;
      } else if (km < 10) {
        distanceBuckets[2]++;
      } else if (km < 20) {
        distanceBuckets[3]++;
      } else {
        distanceBuckets[4]++;
      }
    }

    return AnalyticsStats(
      totalHikes: totalHikes,
      totalDistanceKm: totalDistanceKm,
      totalDuration: totalDuration,
      totalSteps: totalSteps,
      avgDistanceKm: avgDistanceKm,
      avgDuration: avgDuration,
      avgPaceMinPerKm: avgPaceMinPerKm,
      longestByDistance: longestByDistance,
      longestByDuration: longestByDuration,
      bestPace: bestPaceRecord,
      mostSteps: mostStepsValue > 0 ? mostStepsRecord : null,
      mostHikesInOneWeek: mostHikesInOneWeek,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      monthlyDistance: monthlyDistance,
      dayOfWeekCounts: dayOfWeekCounts,
      distanceBuckets: distanceBuckets,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// ISO 8601 week key: "YYYY-WW".
  static String _isoWeekKey(DateTime dt) {
    // Days since Monday of this week's ISO week.
    final dayOfWeek = dt.weekday; // 1=Mon … 7=Sun
    final monday = dt.subtract(Duration(days: dayOfWeek - 1));
    // Week number: day-of-year of the Thursday of this week / 7, rounded up.
    final thursday = monday.add(const Duration(days: 3));
    final yearStart = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(yearStart).inDays + 1;
    final week = ((dayOfYear - 1) ~/ 7) + 1;
    return '${thursday.year}-${week.toString().padLeft(2, '0')}';
  }

  /// Consecutive calendar days ending on or before today that each have at
  /// least one hike. If today has no hike, the streak is 0.
  static int _currentStreak(List<HikeRecord> hikes) {
    final days = _hikeDays(hikes);
    if (days.isEmpty) return 0;

    final today = _dayKey(DateTime.now());
    if (!days.contains(today)) return 0;

    int streak = 0;
    DateTime cursor = DateTime.now();
    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of consecutive calendar days each containing at least one hike.
  static int _longestStreak(List<HikeRecord> hikes) {
    final days = _hikeDays(hikes).toList()..sort();
    if (days.isEmpty) return 0;

    int longest = 1;
    int current = 1;
    for (int i = 1; i < days.length; i++) {
      final prev = _parseDay(days[i - 1]);
      final curr = _parseDay(days[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  /// Returns the set of unique "YYYY-MM-DD" day strings for all hike start times.
  static Set<String> _hikeDays(List<HikeRecord> hikes) {
    return hikes.map((h) => _dayKey(h.startTime)).toSet();
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static DateTime _parseDay(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Build monthly distance buckets covering every month in the filtered range.
  static List<MonthlyBucket> _monthlyDistance(List<HikeRecord> filtered) {
    if (filtered.isEmpty) return [];

    // Sum per month.
    final sums = <String, double>{};
    DateTime? earliest;
    DateTime? latest;

    for (final h in filtered) {
      final key = '${h.startTime.year}-${h.startTime.month.toString().padLeft(2, '0')}';
      sums[key] = (sums[key] ?? 0) + h.distanceMeters / 1000.0;
      if (earliest == null || h.startTime.isBefore(earliest)) {
        earliest = h.startTime;
      }
      if (latest == null || h.startTime.isAfter(latest)) {
        latest = h.startTime;
      }
    }

    // Enumerate every calendar month from earliest to latest (inclusive).
    final result = <MonthlyBucket>[];
    int y = earliest!.year;
    int m = earliest.month;
    while (y < latest!.year || (y == latest.year && m <= latest.month)) {
      final key = '$y-${m.toString().padLeft(2, '0')}';
      result.add(MonthlyBucket(
        year: y,
        month: m,
        distanceKm: sums[key] ?? 0,
      ));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return result;
  }
}
