# offline-weather-cache.md

## User Story

As a hiker in an area with poor cell coverage, I want the Track screen to show the last known weather conditions even when the network is unavailable, so that I still have useful environmental context during my hike.

## Background / Problem

Analysis report item **N2**.

`WeatherService.fetchCurrent()` in `lib/services/weather_service.dart` has no offline fallback. When the network is unavailable, the fetch fails silently (or with a logged error) and the weather display on the Track screen remains blank or shows the last in-memory value until the app is restarted (which also clears the in-memory value). A hiker who starts the app in an area without signal sees no weather data at all, even if the last fetch from 30 minutes ago at the trailhead was successful.

## Requirements

1. After every successful `WeatherService.fetchCurrent()` call, persist the returned `WeatherData` and its fetch timestamp to `SharedPreferences` (via `UserPreferencesService` or directly).
2. On app startup (during `SplashScreen` or first weather fetch attempt), load the cached `WeatherData` from `SharedPreferences`.
3. If a live fetch fails (network error), display the cached `WeatherData` with a "last updated X minutes ago" suffix in the weather description on the Track screen.
4. If no cached data exists and the network is unavailable, display a "No weather data" placeholder (current behaviour).
5. The cached data must be invalidated (ignored) if it is older than 24 hours — stale weather from yesterday is misleading.
6. `WeatherData` serialisation to/from JSON for `SharedPreferences` storage must be added to `lib/models/weather_data.dart`. The model must remain pure Dart (no Flutter imports).

## Non-Goals

- Caching weather data to Hive (SharedPreferences is sufficient for a single record).
- Showing weather history or charts.
- Fetching weather in the background without a GPS fix.

## Design / Implementation Notes

**Files to touch:**
- `lib/models/weather_data.dart` — add `toJson()` / `fromJson()` methods.
- `lib/services/weather_service.dart` (or `WeatherPoller` if extracted) — persist on success, load on startup, fallback on failure.
- `lib/services/user_preferences_service.dart` — add `cachedWeatherJson` and `cachedWeatherTimestamp` fields (or handle directly in `WeatherPoller`).
- `lib/screens/track_screen.dart` — display "last updated" suffix when showing cached data.

**JSON sketch for `WeatherData`:**
```dart
Map<String, dynamic> toJson() => {
  'temperature': temperature,
  'description': description,
  'pressure': pressure,
  'wmoCode': wmoCode,
};

factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
  temperature: json['temperature'] as double,
  description: json['description'] as String,
  pressure: json['pressure'] as double,
  wmoCode: json['wmoCode'] as int,
);
```

**"Last updated" label:** the `WeatherPoller` (or `HikeRecordingController`) passes a `lastFetchedAt` `DateTime` alongside the `WeatherData` to the Track screen, which formats it as "last updated 23 min ago".

## Acceptance Criteria

- [ ] A successful weather fetch persists `WeatherData` to `SharedPreferences`.
- [ ] After enabling airplane mode and restarting the app, the Track screen shows the last known weather with a "last updated X min ago" label.
- [ ] Cached data older than 24 hours is not displayed (the screen falls back to blank / "No weather data").
- [ ] `WeatherData.toJson()` and `WeatherData.fromJson()` round-trip all fields without data loss.
- [ ] `flutter analyze` reports zero issues.
