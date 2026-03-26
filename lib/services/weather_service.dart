import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

/// Static service for fetching current weather data from the Open-Meteo API.
///
/// No API key required. Respects fair-use policy via caller-controlled
/// refresh interval (5 minutes).
class WeatherService {
  /// Fetches current weather for the given coordinates.
  ///
  /// Returns `null` on any failure (network error, non-200 status, or
  /// JSON parse error). The caller is responsible for handling the null
  /// case gracefully.
  static Future<WeatherData?> fetchCurrent(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = _buildUri(latitude, longitude);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      return _parseResponse(response.body);
    } catch (_) {
      return null;
    }
  }

  /// Builds the Open-Meteo API URI for the given coordinates.
  static Uri _buildUri(double latitude, double longitude) {
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,weather_code,surface_pressure',
    });
  }

  /// Parses a JSON response body into a [WeatherData] instance.
  ///
  /// Returns `null` if the JSON structure is unexpected or values are
  /// missing.
  static WeatherData? _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      return WeatherData(
        temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        surfacePressureHpa: (current['surface_pressure'] as num).toDouble(),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
