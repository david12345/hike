# Feature Spec: Smart Stationary Detection for GPS Recording

**Status:** Proposed
**Date:** 2026-03-28
**Depends on:** `heading-gate-release-fix.md` (heading gate must run in release builds for stationary detection to be meaningful)

---

## User Story

As a hiker who takes breaks during a long hike — pausing to eat, check the
map, or enjoy the view — I want the app to automatically reduce GPS polling
when I am stationary, so that my battery lasts longer and my saved route does
not accumulate a cloud of jitter points around my rest spots.

---

## Background / Problem

During an active recording session, `LocationService.trackPosition()` requests
fixes with `distanceFilter: 1` metre and `intervalDuration: 2` seconds. The
GPS chipset runs at near-maximum rate throughout the session. This is correct
while the hiker is moving — it captures tight curves and slow switchbacks — but
is wasteful when the hiker is stationary.

### Problem 1: Battery drain during rest stops

A 10-minute rest stop at 1 Hz GPS generates approximately 300 platform
callbacks. The heading-change gate (`heading-gate-release-fix.md`) will reject
most of these fixes once it runs in release builds, but the GPS chipset itself
still wakes up and delivers them to the Fused Location Provider pipeline,
consuming power. Reducing the fix rate during stationary periods at the platform
level (via `distanceFilter` and `intervalDuration`) would let the chipset
sleep more.

### Problem 2: Jitter accumulation at rest stops

Even with the accuracy gate (30 m threshold), fixes during a stationary period
at a good-sky location typically have 5–15 m accuracy. These pass the gate.
The 1 m `distanceFilter` suppresses many of them but not all — the GPS jitter
radius is typically 2–5 m, so the platform will still deliver occasional fixes
that have "moved" 1 m purely due to noise. The Douglas-Peucker simplification
at save time (`path-simplification-dp.md`) removes some of these, but
simplification with epsilon = 3 m will still leave a small cluster of points
at each rest stop.

### Current state

`TrackingState._startRecordingStream` uses a single static stream with fixed
parameters for the entire session. There is no mechanism to detect stationarity
or to reconfigure the stream without stopping and restarting the recording.

The ambient stream (`trackPositionAmbient`) already uses `distanceFilter: 50`
and `LocationAccuracy.medium`, but it is only active when not recording.

The `_ambientSpeed` field in `TrackingState` provides a running speed estimate
from each GPS fix. `pos.speed` from geolocator is the instantaneous speed
reported by the FLP (computed from Doppler shift or successive positions).

---

## Proposed Design

### Overview

Introduce a **stationary timer** inside `TrackingState`. When a configurable
number of consecutive accepted fixes all report `pos.speed < kStationarySpeedThreshold`,
start a debounce timer. If the hiker remains below the speed threshold for
`kStationaryDebounceSeconds`, switch the recording stream to a lower-frequency
mode. When any accepted fix exceeds the speed threshold, switch back to
high-frequency mode immediately.

This is fully transparent to `HikeRecordingController` and all screens — the
stream mode change happens inside `TrackingState` without surfacing any new
public API.

### Constants (`lib/utils/constants.dart`)

```dart
/// Speed threshold (m/s) below which the hiker is considered stationary.
///
/// 0.5 m/s (1.8 km/h) is a deliberate walk; below this the hiker is
/// stopping or shuffling. At 0.5 m/s the heading reading is also
/// unreliable, so this threshold matches the conditions where dense
/// GPS sampling has no fidelity benefit.
const kStationarySpeedThreshold = 0.5;

/// Elapsed seconds of sub-threshold speed before the recording stream
/// switches to stationary (low-frequency) mode.
///
/// 10 seconds prevents mode-switching during momentary pauses (tying a
/// lace, looking at the phone) while being short enough to avoid capturing
/// many unnecessary fixes before the switch takes effect.
const kStationaryDebounceSecs = 10;

/// Distance filter (metres) used in stationary recording mode.
///
/// 10 m means the platform delivers a fix only if the device has genuinely
/// moved 10 m — effectively suppressing jitter and chipset wake-ups
/// during a rest stop.
const kStationaryDistanceFilterMetres = 10;

/// Time interval (seconds) used in stationary recording mode (Android only).
///
/// 10 seconds is a low-power rate that still captures the moment the hiker
/// resumes walking (first fix within 10 s of movement).
const kStationaryTimeIntervalSeconds = 10;
```

### State machine

```
MOVING mode (default on startRecording):
  stream: distanceFilter=1, intervalDuration=2s
  on fix: pos.speed < kStationarySpeedThreshold  → start/increment stationaryCounter
          pos.speed >= kStationarySpeedThreshold → reset stationaryCounter
          stationaryCounter >= (kStationaryDebounceSecs / kRecordingTimeIntervalSeconds):
              → transition to STATIONARY mode

STATIONARY mode:
  stream: distanceFilter=10, intervalDuration=10s
  on fix: pos.speed >= kStationarySpeedThreshold → transition back to MOVING mode
          (the single fix that triggers the transition is accepted normally)
```

### Stream restart approach

Geolocator does not support changing `locationSettings` on a live stream. The
stream must be cancelled and restarted with new settings. `TrackingState` already
performs this operation (ambient ↔ recording transition in `startRecording` and
`stopRecording`). The same pattern applies here:

```dart
void _switchToStationaryMode() {
  _streamSub?.cancel();
  _stationaryMode = true;
  _stationaryCounter = 0;
  _streamSub = LocationService.trackPositionStationary().listen(_onRecordingFix);
  debugPrint('GPS: switched to stationary mode (low-frequency recording)');
}

void _switchToMovingMode() {
  _streamSub?.cancel();
  _stationaryMode = false;
  _streamSub = LocationService.trackPosition().listen(_onRecordingFix);
  debugPrint('GPS: switched to moving mode (high-frequency recording)');
}
```

A new `trackPositionStationary()` static method is added to `LocationService`:

```dart
/// Low-frequency recording stream for stationary periods.
///
/// Uses a 10 m distance filter and 10 s interval to minimise GPS chipset
/// wake-ups while the hiker is at rest.
static Stream<Position> trackPositionStationary() {
  if (Platform.isAndroid) {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: kStationaryDistanceFilterMetres,
        intervalDuration: const Duration(seconds: kStationaryTimeIntervalSeconds),
      ),
    );
  }
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kStationaryDistanceFilterMetres,
    ),
  );
}
```

### Integration with the recording stream listener

The recording stream listener (`_startRecordingStream`) is refactored to call a
shared `_onRecordingFix(Position pos)` method. This avoids duplicating the
accuracy gate, adaptive buffer, gap detection, and heading logic for the two
stream modes.

### No gap markers on mode switch

Switching stream modes causes a brief subscription gap (typically < 200 ms on
Android). This must not trigger the 30-second gap detector. The
`_lastAcceptedFixAt` timestamp is preserved across the mode switch — the new
stream listener continues to compare against the last fix from the previous mode.

---

## Non-Goals

- Pausing the recording entirely when stationary (the hiker may be resting on a
  ridge; elapsed time still accumulates correctly in this spec).
- Showing a "stationary / moving" indicator on the Track screen.
- Applying stationary detection to the ambient stream (already handled by
  `ambient-gps-background-pause.md` and the 50 m `distanceFilter`).
- Changing the heading-change gate threshold based on mode.

---

## Design / Implementation Notes

**Files to touch:**
- `lib/utils/constants.dart` — add four new constants.
- `lib/services/location_service.dart` — add `trackPositionStationary()`.
- `lib/services/tracking_state.dart` — add `_stationaryMode`, `_stationaryCounter`,
  `_switchToStationaryMode()`, `_switchToMovingMode()` private members; extract
  shared `_onRecordingFix(Position pos)` method from the inline stream listener;
  call `_stationaryMode = false` and `_stationaryCounter = 0` in `startRecording()`
  and `stopRecording()`.

**No changes needed in:**
- `HikeRecordingController` — transparent to mode changes.
- `HikeRecord` / Hive schema — points are stored identically in both modes.
- Checkpoint timer — still fires every 30 s regardless of mode.
- Gap detection — `_lastAcceptedFixAt` is preserved across mode switches.

**Stream cancel/restart safety:**
The existing `_streamSub?.cancel()` pattern in `_startAmbientStream` and
`_startRecordingStream` is idempotent. Mode switches follow the same pattern.
The brief subscription gap between cancel and re-listen is < 200 ms — well below
the 2 s `kRecordingTimeIntervalSeconds` and the 30 s `kGapThresholdSeconds`.

**Interaction with adaptive accuracy buffer:**
`_accuracyBuffer` and `_bufferStartedAt` are cleared at the same time as
`_stationaryCounter` on `startRecording()` and `stopRecording()`. A mode switch
mid-buffer does not flush the buffer — the buffer holds fixes regardless of mode.

---

## Acceptance Criteria

- [ ] Standing still for 10 seconds during recording causes a `debugPrint`
      confirming the switch to stationary mode.
- [ ] In stationary mode, GPS callbacks arrive at approximately 10 s intervals
      rather than 2 s intervals (verifiable via logcat timestamp).
- [ ] Starting to walk after a rest stop immediately triggers a switch back to
      moving mode on the first fix that exceeds `kStationarySpeedThreshold`.
- [ ] The recorded route has no gap at a rest stop (the gap-detection threshold
      of 30 s is not triggered during a 10 s stationary interval).
- [ ] Jitter points during a 5-minute rest stop are fewer than with the
      current always-on 1 m / 2 s stream (manual comparison: record a rest
      stop, count points, compare).
- [ ] The elapsed timer on the Track screen advances normally during stationary
      mode — switching streams does not affect the timer.
- [ ] `startRecording()` always begins in moving mode regardless of the state
      at the end of the previous session.
- [ ] `flutter analyze` reports zero issues.

---

## Acceptance Criteria — Edge Cases

- [ ] Mode switches during an ongoing adaptive-buffer window do not lose buffered
      fixes.
- [ ] Recording a hike that starts stationary (hiker not moving for first 30 s)
      switches to stationary mode within `kStationaryDebounceSecs` seconds.
- [ ] Rapid alternation between moving and stationary (walking 5 s, stopping 5 s,
      walking 5 s) does not cause stream thrashing — the debounce timer prevents
      switching until the hiker has been below threshold for a full 10 s.

---

## Battery Impact Estimate

At 4 km/h on a 6-hour hike with two 20-minute rest stops:
- Without this spec: 6 h × 3600 s/h / 2 s interval = ~10,800 platform callbacks.
- With this spec: 40 min stationary × 60 s/min / 10 s interval = 240 stationary
  callbacks; 5.3 h moving × 1800 callbacks/h ≈ 9,540 moving callbacks.
  Total ≈ 9,780 callbacks — approximately 10% reduction.
- The larger gain is at the chipset level: the FLP can extend its internal
  sampling interval during the 10 s window, reducing radio wake-ups.
