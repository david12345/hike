# Feature Spec: GPS Accuracy Field Validation

**Status:** Proposed
**Date:** 2026-03-28

---

## User Story

As a hiker recording a route in challenging terrain, I want the app to use the
GPS chipset's own speed and vertical accuracy estimates — rather than fixed
threshold constants — to decide when a heading-change trigger or altitude update
is reliable, so that low-quality fixes do not generate spurious recording points
or jumpy altitude readings.

---

## Background / Problem

The recording pipeline in `lib/services/tracking_state.dart` and
`lib/services/hike_recording_controller.dart` already reads `Position.accuracy`
(horizontal) from each GPS fix and uses it in two ways:

1. The accuracy gate rejects fixes with `pos.accuracy > kMaxAcceptableAccuracyMetres`
   (30 m) before they enter the route.
2. `accuracyNotifier` exposes the last raw accuracy to the Track screen.

However, the `Position` object from geolocator exposes two additional accuracy
fields that are currently ignored:

- `Position.speedAccuracy` (`double`, metres per second) — the chipset's own
  estimate of the uncertainty in `pos.speed`. On Android this is
  `Location.getSpeedAccuracyMetersPerSecond()`, available since API 26.
  On devices or APIs where it is unavailable, geolocator returns `0.0`.

- `Position.altitudeAccuracy` (`double`, metres) — the chipset's own estimate
  of the uncertainty in `pos.altitude`. On Android this is
  `Location.getVerticalAccuracyMeters()`, available since API 26.
  On devices or APIs where it is unavailable, geolocator returns `0.0`.

### Problem 1: Heading-change trigger uses `pos.speed` without a speed quality check

The heading-change gate in `TrackingState._startRecordingStream` (after the
`heading-gate-release-fix.md` fix is applied) reads:

```dart
final isMoving = pos.speed >= kMinSpeedForHeadingTrigger;
```

`kMinSpeedForHeadingTrigger = 0.3 m/s` is a hard constant. It guards against
chipset heading noise at near-zero speed, but it does not account for the
case where `pos.speed = 0.8 m/s` but `pos.speedAccuracy = 1.5 m/s`. In this
situation the chipset is telling us that the speed estimate could be anywhere
from 0 to 2.3 m/s — the hiker may be stationary. The heading-change trigger
should not fire on a speed reading that is less reliable than the threshold
it is guarding.

### Problem 2: Altitude EMA applies equally to high- and low-quality altitude fixes

The EMA in `TrackingState._updateFromPosition` smooths altitude unconditionally:

```dart
_ambientAltitude = _ambientAltitude == 0.0
    ? pos.altitude
    : _ambientAltitude * (1 - _kAltitudeEmaAlpha) + pos.altitude * _kAltitudeEmaAlpha;
```

When `pos.altitudeAccuracy` is large (e.g. 50 m — poor barometric or satellite
geometry), applying a 20% weight to that noisy altitude reading shifts the EMA
value further from the true altitude than doing nothing would. A fix with
`altitudeAccuracy > kMaxAcceptableAccuracyMetres` should contribute 0% to the
EMA, preserving the last good estimate.

---

## Requirements

### R1 — Speed quality guard for heading-change trigger

In `TrackingState._startRecordingStream`, extend the `isMoving` check to
incorporate `pos.speedAccuracy`:

- If `pos.speedAccuracy > 0.0` (chipset provided a speed accuracy value), only
  treat the hiker as moving if `pos.speed - pos.speedAccuracy >= kMinSpeedForHeadingTrigger`.
  This means the lower bound of the speed estimate still exceeds the threshold.
- If `pos.speedAccuracy == 0.0` (accuracy unavailable — older API or chipset),
  fall back to the existing `pos.speed >= kMinSpeedForHeadingTrigger` comparison.

Introduce a constant for this logic. No new exported constant is needed; the
guard is contained within the fix-acceptance path.

### R2 — Altitude EMA quality gate

In `TrackingState._updateFromPosition`, skip the EMA update when
`pos.altitudeAccuracy > kMaxAcceptableAccuracyMetres`:

- If `pos.altitudeAccuracy == 0.0` (unavailable), apply the EMA unconditionally
  as today (preserve existing behaviour on older hardware).
- If `pos.altitudeAccuracy > 0.0 && pos.altitudeAccuracy > kMaxAcceptableAccuracyMetres`,
  skip this fix's contribution to the altitude EMA. Keep `_ambientAltitude`
  unchanged.
- If `pos.altitudeAccuracy > 0.0 && pos.altitudeAccuracy <= kMaxAcceptableAccuracyMetres`,
  apply the EMA normally.

This reuses the existing `kMaxAcceptableAccuracyMetres` constant, avoiding a
separate altitude accuracy threshold constant.

### R3 — Expose `speedAccuracy` and `altitudeAccuracy` in debug log

Extend the existing `debugPrint` in `_updateFromPosition` (or the accuracy-gate
drop log) to include `pos.speedAccuracy` and `pos.altitudeAccuracy` when they
are non-zero. This aids field debugging without adding any new UI.

### R4 — No behaviour change on devices where accuracy fields return 0.0

Both guards must degrade gracefully to the current behaviour when the chipset
does not provide speed or altitude accuracy. No error, no crash, no log noise.

---

## Non-Goals

- Showing `speedAccuracy` or `altitudeAccuracy` in the Track screen UI.
- Gating the route's horizontal coordinates on `altitudeAccuracy`.
- Using `Position.heading` accuracy (not exposed by geolocator on Android).
- Supporting iOS (the app is Android-only).

---

## Design / Implementation Notes

**Files to touch:**
- `lib/services/tracking_state.dart` — two changes:
  1. In `_startRecordingStream`, extend `isMoving` guard (R1).
  2. In `_updateFromPosition`, add altitude accuracy gate before EMA (R2, R3).

**Geolocator API surface:**
The `geolocator` package (`^13.0.1`, `geolocator_android: ^4.6.2`) exposes
`Position.speedAccuracy` and `Position.altitudeAccuracy` as `double` fields.
Both return `0.0` when the underlying Android API (`Location.getSpeedAccuracyMetersPerSecond()`
and `Location.getVerticalAccuracyMeters()`) is unavailable (API < 26 or chipset
limitation). No package upgrade is required.

**R1 implementation sketch:**

```dart
// In _startRecordingStream, good-fix path:
final bool isMoving;
if (pos.speedAccuracy > 0.0) {
  // Use lower bound of speed estimate.
  isMoving = (pos.speed - pos.speedAccuracy) >= kMinSpeedForHeadingTrigger;
} else {
  // Accuracy unavailable — use raw speed (existing behaviour).
  isMoving = pos.speed >= kMinSpeedForHeadingTrigger;
}
```

**R2 implementation sketch:**

```dart
// In _updateFromPosition, after setting _ambientSpeed:
final bool altitudeIsReliable =
    pos.altitudeAccuracy == 0.0 || // unavailable → assume good
    pos.altitudeAccuracy <= kMaxAcceptableAccuracyMetres;

if (altitudeIsReliable) {
  _ambientAltitude = _ambientAltitude == 0.0
      ? pos.altitude
      : _ambientAltitude * (1 - _kAltitudeEmaAlpha) +
            pos.altitude * _kAltitudeEmaAlpha;
}
// else: keep previous EMA value unchanged
```

**Interaction with heading-gate-release-fix.md:**
This spec depends on `heading-gate-release-fix.md` being applied first,
because R1 modifies the same `isMoving` variable that the heading gate uses.
The two changes should be implemented together or in sequence.

---

## Acceptance Criteria

- [ ] When `pos.speedAccuracy = 0.0`, heading-trigger behaviour is identical to
      before this change (regression-free).
- [ ] When `pos.speedAccuracy` is greater than `pos.speed - kMinSpeedForHeadingTrigger`,
      the heading-change trigger does not fire (verifiable via debug log).
- [ ] When `pos.altitudeAccuracy = 0.0`, altitude EMA behaviour is identical to
      before this change.
- [ ] When `pos.altitudeAccuracy > kMaxAcceptableAccuracyMetres`, the altitude
      display on the Track screen does not jump on that fix.
- [ ] No crash or error when both fields return `0.0` simultaneously.
- [ ] `flutter analyze` reports zero issues.
