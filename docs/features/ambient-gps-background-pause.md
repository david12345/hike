# ambient-gps-background-pause.md

## User Story

As a hiker who leaves the app running between hikes, I want the ambient GPS stream to pause automatically when I background the app, so that my battery is not drained by unnecessary location updates while the app is not visible.

## Background / Problem

Analysis report item **H4**.

`lib/services/tracking_state.dart` (lines 260–268) starts an ambient GPS stream (50 m distanceFilter, medium accuracy) that runs continuously once the app is launched, even when the user has backgrounded the app between hikes. Unlike the recording stream (backed by a foreground service with a legitimate background-location justification), the ambient stream serves only the Map screen's live-location dot and the Track screen's pre-recording sensor display. Neither screen is visible when the app is backgrounded, making the stream wasteful.

## Requirements

1. Add a `WidgetsBindingObserver` to `TrackingState` (it is a singleton ChangeNotifier).
2. Implement `didChangeAppLifecycleState`:
   - On `AppLifecycleState.paused` or `hidden`: if **not actively recording**, cancel the ambient stream subscription.
   - On `AppLifecycleState.resumed`: if **not actively recording**, restart the ambient stream.
3. If a recording is in progress, the ambient stream must not be paused (the recording stream already provides position updates; pausing ambient is moot but must not break recording-mode listeners).
4. The `WidgetsBindingObserver` must be registered in `TrackingState`'s constructor or `init()` and removed in `dispose()`.
5. Add `debugPrint` on stream pause and resume events for easier debugging.
6. The `isRecording` flag (or equivalent) already on `TrackingState` must be the guard condition.

## Non-Goals

- Pausing the foreground recording stream on background (it must stay alive for GPS recording).
- Pausing the compass stream on background (covered by `compass-stream-pause-resume.md`).
- Adding a user toggle to disable ambient GPS.

## Design / Implementation Notes

**Files to touch:**
- `lib/services/tracking_state.dart` — add `with WidgetsBindingObserver`, implement `didChangeAppLifecycleState`, add `_pauseAmbient()` and `_resumeAmbient()` private methods.

**Key concern:** `TrackingState` is a singleton that lives for the app lifetime. Ensure `WidgetsBinding.instance.addObserver(this)` is called after `WidgetsBinding.instance` is available (i.e. after `WidgetsFlutterBinding.ensureInitialized()` in `main()`).

**State machine:**
```
App foregrounded, not recording  → ambient stream ON
App backgrounded, not recording  → ambient stream OFF
App foregrounded, recording      → ambient stream ON (or irrelevant)
App backgrounded, recording      → ambient stream ON (foreground service handles GPS)
```

## Acceptance Criteria

- [ ] Backgrounding the app without an active recording stops the ambient location stream (verified via Android battery stats or `debugPrint` confirming subscription cancellation).
- [ ] Returning to the foreground restarts the ambient stream and the Map screen's live-location dot updates again.
- [ ] Starting a recording while backgrounded (via a notification action or Auto) is unaffected.
- [ ] No `WidgetsBindingObserver` leaks.
- [ ] `flutter analyze` reports zero issues.
