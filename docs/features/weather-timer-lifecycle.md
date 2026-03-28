# weather-timer-lifecycle.md

## User Story

As a hiker recording a long hike with the screen off, I want the app to stop making weather API requests in the background, so that my mobile data and battery are not wasted on weather updates that nobody can see.

## Background / Problem

Analysis report item **H3**.

`lib/services/hike_recording_controller.dart` (lines 177–183) starts a `Timer.periodic` that calls `WeatherService.fetchCurrent()` roughly every 5 minutes or after significant movement. This timer runs on the main Dart isolate continuously throughout a recording session, including when the app is backgrounded (screen off, app in background via the Android foreground service). Weather data is only ever displayed on the Track screen, which is not visible when backgrounded. A 6-hour hike with the screen off can generate up to 72 unnecessary HTTP requests and their associated radio wake-ups.

## Requirements

1. Add an `AppLifecycleState` observer to `HikeRecordingController` (or its enclosing context) using `WidgetsBindingObserver`.
2. In the weather timer callback, check the current `AppLifecycleState`: if the state is `paused`, `inactive`, or `hidden`, skip the fetch entirely and return early.
3. When the app returns to `resumed` state, trigger an immediate weather fetch if the last fetch was more than 5 minutes ago (to refresh the displayed data promptly).
4. The timer itself must remain running (do not start/stop it on lifecycle changes) — only the fetch inside the callback is skipped.
5. The lifecycle observer must be properly registered (`WidgetsBinding.instance.addObserver`) and disposed (`removeObserver`) to avoid memory leaks.
6. Add `debugPrint` when a fetch is skipped due to background state.

## Non-Goals

- Pausing the GPS recording stream on background (that is covered by `ambient-gps-background-pause.md`).
- Cancelling the weather timer entirely during background (the timer is cheap to keep alive).
- Implementing an offline weather cache (covered by `offline-weather-cache.md`).

## Design / Implementation Notes

**Files to touch:**
- `lib/services/hike_recording_controller.dart` — add `WidgetsBindingObserver` mixin, implement `didChangeAppLifecycleState`, track current state in a field, check it in the timer callback.

**Alternatively**, if `WeatherPoller` is extracted first (see `weather-poller-extraction.md`), implement the lifecycle check there.

**Pattern reference:** `lib/services/tracking_state.dart` — if it already uses `WidgetsBindingObserver` for H4 (`ambient-gps-background-pause.md`), apply the same mixin here.

**Code sketch in timer callback:**
```dart
_weatherTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
  if (_lifecycleState == AppLifecycleState.paused ||
      _lifecycleState == AppLifecycleState.hidden) {
    debugPrint('[WeatherPoller] skipping fetch — app is backgrounded');
    return;
  }
  await _fetchWeather();
});
```

## Acceptance Criteria

- [ ] Starting a recording, backgrounding the app, and waiting 10 minutes generates zero weather HTTP requests (verified via network log or `debugPrint` output).
- [ ] Bringing the app back to the foreground triggers a weather fetch within 5 seconds if the last fetch was > 5 minutes ago.
- [ ] No `WidgetsBindingObserver` leaks: the observer is removed in `dispose()`.
- [ ] `flutter analyze` reports zero issues.
