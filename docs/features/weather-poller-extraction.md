# weather-poller-extraction.md

## User Story

As a developer maintaining the Hike app, I want weather polling to live in its own service with a clear `ValueNotifier` API, so that `HikeRecordingController` is smaller and the weather fetch logic is independently testable.

## Background / Problem

Analysis report item **M1 (part 2)**.

`lib/services/hike_recording_controller.dart` is approximately 600 lines. Weather polling — the `Timer.periodic`, the 5-minute / 1 km fetch guard, the `WeatherData` state, and the `WeatherService` call — is one of its five responsibilities. This logic has no testable seam because it is woven into the recording lifecycle and shares `setState` / `notifyListeners` with unrelated recording concerns.

## Requirements

1. Create `lib/services/weather_poller.dart` containing a `WeatherPoller` class.
2. `WeatherPoller` must own:
   - The `Timer.periodic` for periodic fetches.
   - The 5-minute guard and 1 km movement guard logic.
   - `ValueNotifier<WeatherData?> weatherNotifier` — the latest weather result (null before first fetch).
   - `start(double lat, double lon)` — called on first GPS fix.
   - `updatePosition(double lat, double lon)` — called on subsequent GPS fixes to check the 1 km guard.
   - `stop()` — cancels the timer.
   - `dispose()` — stops the timer and disposes the notifier.
3. The `AppLifecycleState` background-skip logic from `weather-timer-lifecycle.md` is implemented inside `WeatherPoller` (not in `HikeRecordingController`).
4. `HikeRecordingController` delegates weather operations to `WeatherPoller` — it no longer owns weather state or the timer.
5. `TrackScreen` reads `WeatherPoller.weatherNotifier` for the weather display.
6. `WeatherPoller` is instantiated once (alongside `HikeRecordingController`) and accessible as a singleton or injected parameter.
7. `HikeRecordingController` shrinks by at least 60 additional lines after this extraction (on top of the `CompassManager` extraction).

## Non-Goals

- Changing `WeatherService` itself.
- Implementing an offline weather cache (covered by `offline-weather-cache.md`).
- Extracting pedometer or checkpoint-save logic (covered by `recording-controller-deduplication.md`).

## Design / Implementation Notes

**New file:** `lib/services/weather_poller.dart`

**Files to touch:**
- `lib/services/hike_recording_controller.dart` — remove weather timer, guard fields, `WeatherData` notifier; delegate to `WeatherPoller`.
- `lib/main.dart` — instantiate `WeatherPoller`.
- `lib/screens/track_screen.dart` — update weather source to `WeatherPoller.weatherNotifier`.

**Dependency:** `WeatherPoller` depends on `WeatherService` (injected or accessed via singleton).

**Relationship with `weather-timer-lifecycle.md`:** implement the `AppLifecycleState` check inside `WeatherPoller.start()` timer callback, as described in that spec.

## Acceptance Criteria

- [ ] `lib/services/weather_poller.dart` exists with `start()`, `updatePosition()`, `stop()`, `weatherNotifier`, and `dispose()`.
- [ ] `HikeRecordingController` contains no weather timer, no weather `ValueNotifier`, and no `WeatherService` calls.
- [ ] The Track screen still displays weather data during recording.
- [ ] Weather fetches are skipped when the app is backgrounded (per `weather-timer-lifecycle.md` acceptance criteria).
- [ ] `flutter analyze` reports zero issues.
