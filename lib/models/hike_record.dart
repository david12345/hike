import 'package:hive/hive.dart';

part 'hike_record.g.dart';

@HiveType(typeId: 0)
class HikeRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime startTime;

  @HiveField(3)
  DateTime? endTime;

  @HiveField(4)
  double distanceMeters;

  @HiveField(5)
  List<double> latitudes;

  @HiveField(6)
  List<double> longitudes;

  @HiveField(7, defaultValue: 0)
  int steps;

  @HiveField(8, defaultValue: 0.0)
  double calories;

  HikeRecord({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    this.distanceMeters = 0,
    List<double>? latitudes,
    List<double>? longitudes,
    this.steps = 0,
    this.calories = 0.0,
  })  : latitudes = latitudes ?? [],
        longitudes = longitudes ?? [];

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get durationFormatted {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get distanceFormatted {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String get stepsFormatted => steps > 0 ? '$steps steps' : '--';
  String get caloriesFormatted => calories > 0 ? '${calories.toStringAsFixed(0)} kcal' : '--';
}
