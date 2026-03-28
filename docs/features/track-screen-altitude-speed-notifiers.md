# track-screen-altitude-speed-notifiers.md

## User Story

As a developer maintaining the Hike app, I want `TrackScreen` to get altitude and speed data exclusively from `HikeRecordingController`, so that the screen has a single declared dependency and does not reach past the controller into `TrackingState` directly.

## Background / Problem

Analysis report item **M3**.

`lib/screens/track_screen.dart` (lines 151 and 239) reads `TrackingState.instance.ambientAltitude` and `TrackingState.instance.ambientSpeed` directly inside `ValueListenableBuilder` callbacks for `positionNotifier`. This bypasses the `HikeRecordingController` ValueNotifier contract that the rest of the Track screen already follows. It creates a hidden dependency on `TrackingState` from a screen that should only know about `HikeRecordingController`, making the coupling harder to see and test.

## Requirements

1. Add `ValueNotifier<double> altitudeNotifier` to `HikeRecordingController`, initialised to `0.0`.
2. Add `ValueNotifier<double> speedNotifier` to `HikeRecordingController`, initialised to `0.0`.
3. Both notifiers are updated inside the `_onTrackingChanged` callback (or equivalent method) that already fires on every GPS fix, by reading from `TrackingState.instance` at that point.
4. The notifiers are disposed in `HikeRecordingController.dispose()`.
5. `TrackScreen` replaces the direct `TrackingState.instance.ambientAltitude` and `TrackingState.instance.ambientSpeed` reads with `ValueListenableBuilder` (or inline reads from the notifiers) against `altitudeNotifier` and `speedNotifier`.
6. `TrackScreen` must not import `TrackingState` for the purpose of reading altitude or speed after this change.

## Non-Goals

- Moving all `TrackingState` access out of `TrackScreen` in one pass — only altitude and speed are in scope here.
- Adding EMA smoothing to the notifiers (already handled by `altitude-ema-smoothing.md`).
- Exposing these notifiers to other screens.

## Design / Implementation Notes

**Files to touch:**
- `lib/services/hike_recording_controller.dart` — add `altitudeNotifier`, `speedNotifier`; update `_onTrackingChanged`.
- `lib/screens/track_screen.dart` — update altitude and speed reads.

**Sketch in `_onTrackingChanged`:**
```dart
void _onTrackingChanged() {
  altitudeNotifier.value = TrackingState.instance.ambientAltitude;
  speedNotifier.value = TrackingState.instance.ambientSpeed;
  notifyListeners();
}
```

**Note:** if `CompassManager` and `WeatherPoller` are extracted first, `_onTrackingChanged` may already be a thin method. Add the notifier updates there.

## Acceptance Criteria

- [ ] `HikeRecordingController` exposes `altitudeNotifier` and `speedNotifier`.
- [ ] `TrackScreen` contains no direct access to `TrackingState.instance.ambientAltitude` or `TrackingState.instance.ambientSpeed`.
- [ ] Altitude and speed values on the Track screen update live during recording.
- [ ] `flutter analyze` reports zero issues.
