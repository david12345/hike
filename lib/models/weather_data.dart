/// Ephemeral model holding current weather data from Open-Meteo API.
///
/// Not persisted to Hive. Lives only in widget state.
class WeatherData {
  /// Current temperature in degrees Celsius.
  final double temperatureCelsius;

  /// WMO weather interpretation code.
  final int weatherCode;

  /// Surface-level air pressure in hectopascals.
  final double surfacePressureHpa;

  /// Timestamp when this data was fetched from the API.
  final DateTime fetchedAt;

  /// Creates a [WeatherData] instance.
  WeatherData({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.surfacePressureHpa,
    required this.fetchedAt,
  });

  /// Human-readable description derived from the WMO [weatherCode].
  String get weatherDescription {
    return _wmoDescriptions[weatherCode] ?? 'Unknown';
  }

  /// WMO weather code to human-readable description mapping.
  static const Map<int, String> _wmoDescriptions = {
    0: 'Clear sky',
    1: 'Mainly clear',
    2: 'Partly cloudy',
    3: 'Overcast',
    45: 'Fog',
    48: 'Fog',
    51: 'Drizzle',
    53: 'Drizzle',
    55: 'Drizzle',
    56: 'Freezing drizzle',
    57: 'Freezing drizzle',
    61: 'Rain',
    63: 'Rain',
    65: 'Rain',
    66: 'Freezing rain',
    67: 'Freezing rain',
    71: 'Snow',
    73: 'Snow',
    75: 'Snow',
    77: 'Snow grains',
    80: 'Rain showers',
    81: 'Rain showers',
    82: 'Rain showers',
    85: 'Snow showers',
    86: 'Snow showers',
    95: 'Thunderstorm',
    96: 'Thunderstorm with hail',
    99: 'Thunderstorm with hail',
  };
}
