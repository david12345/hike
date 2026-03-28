# compass-manager-extraction.md

## User Story

As a developer maintaining the Hike app, I want compass lifecycle management to live in its own service, so that `HikeRecordingController` is smaller and focused, and the compass can be paused and resumed without calling back into the recording controller from the navigation layer.

## Background / Problem

Analysis report item **M1 (part 1)**.

`lib/services/hike_recording_controller.dart` is approximately 600 lines and manages five distinct responsibilities. Compass management — starting the heading stream, throttling updates, tracking the current heading in a `ValueNotifier`, and pausing/resuming on tab switches — is one of those responsibilities. Currently `_HomePageState` in `lib/main.dart` calls `HikeRecordingController.pauseCompass()` and `resumeCompass()` directly when the user navigates away from or back to the Track tab. This creates an unnecessary coupling between the navigation layer and the recording controller.

## Requirements

1. Create `lib/services/compass_manager.dart` containing a `CompassManager` class.
2. `CompassManager` must own:
   - The `CompassService` stream subscription.
   - `ValueNotifier<double?> headingNotifier` — the current heading, nullable (null when unavailable).
   - `pause()` and `resume()` public methods.
   - `dispose()` that cancels the subscription and disposes the notifier.
3. `CompassManager` is instantiated once (alongside `HikeRecordingController`) and injected or accessed as a singleton.
4. `HikeRecordingController` delegates compass operations to `CompassManager` — it no longer directly subscribes to `CompassService`.
5. `_HomePageState` calls `CompassManager.pause()` / `resume()` instead of `HikeRecordingController.pauseCompass()` / `resumeCompass()`. The `pauseCompass`/`resumeCompass` public methods on `HikeRecordingController` are removed.
6. `TrackScreen` reads `CompassManager.headingNotifier` instead of the heading notifier currently on `HikeRecordingController` (or the path that delivers it).
7. `HikeRecordingController` shrinks by at least 60 lines after this extraction.

## Non-Goals

- Extracting `WeatherPoller` in the same PR (covered by `weather-poller-extraction.md`).
- Changing the compass throttle logic (1° threshold) — preserve existing behaviour.
- Modifying `CompassService` or `CompassPainter`.

## Design / Implementation Notes

**New file:** `lib/services/compass_manager.dart`

**Files to touch:**
- `lib/services/hike_recording_controller.dart` — remove compass fields, subscription, and pause/resume methods; delegate to `CompassManager`.
- `lib/main.dart` — instantiate `CompassManager`; update tab-switch callbacks to call `CompassManager.pause()` / `resume()`.
- `lib/screens/track_screen.dart` — update heading source to `CompassManager.headingNotifier`.

**Initialisation:** `CompassManager` is created in `main.dart` (or `SplashScreen`) alongside `HikeRecordingController` and passed in as a parameter or exposed as a singleton via `CompassManager.instance`.

## Acceptance Criteria

- [ ] `lib/services/compass_manager.dart` exists with `pause()`, `resume()`, `headingNotifier`, and `dispose()`.
- [ ] `HikeRecordingController` contains no compass stream subscription, no heading `ValueNotifier`, no `pauseCompass()`, and no `resumeCompass()` methods.
- [ ] Navigating away from the Track tab pauses the compass heading stream (verified via `debugPrint` or no heading updates while on another tab).
- [ ] Navigating back to the Track tab resumes compass updates within one heading event.
- [ ] `flutter analyze` reports zero issues.
