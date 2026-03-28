# heading-gate-release-fix.md

## User Story

As a hiker, I want the heading-change filter to actually reduce unnecessary GPS fixes on straight trail sections in the released app, so that my battery lasts longer on full-day hikes.

## Background / Problem

Analysis report item **C3**.

In `lib/services/tracking_state.dart` (lines 350–361) the heading-change gate — which is supposed to reject fixes that don't represent a meaningful direction change, thereby reducing GPS chip wake-ups on straight sections — is wrapped inside an `assert` block. `assert` statements are stripped from Dart release builds. This means the gate is a complete no-op in production: every GPS fix is unconditionally accepted via `_acceptFix` at line 361, and the GPS chip fires at near-maximum rate (1 m / 2 s) for the entire duration of every hike, regardless of trail shape. The spec `gps-recording-density.md` that introduced this guard intended it to run in release builds.

## Requirements

1. Move the heading-change guard logic out of the `assert` block so it executes in both debug and release builds.
2. The guard logic itself must not change: fixes are accepted when (a) heading change >= threshold (10°), (b) speed is above the guard threshold (0.3 m/s), or (c) another acceptance condition already passes (distance or time interval).
3. The `assert` block must be removed or replaced — do not simply duplicate the logic inside and outside `assert`.
4. Add an inline comment explaining why the guard is unconditional (i.e. intentional release-build behaviour).
5. Verify with `flutter analyze` that no new lint warnings are introduced.

## Non-Goals

- Changing the heading threshold, speed guard value, distance filter, or time interval.
- Adding a user-configurable heading sensitivity setting.
- Altering any other fix-acceptance logic in `tracking_state.dart`.

## Design / Implementation Notes

**Files to touch:**
- `lib/services/tracking_state.dart` — lines 350–361.

The fix is a small mechanical change: extract the guard condition from the `assert` body into the surrounding conditional flow. For example:

```dart
// Before (assert is a no-op in release):
assert(() {
  if (headingDelta < kHeadingThreshold && speed < kSpeedGuard) {
    return false; // reject fix
  }
  return true;
}());
_acceptFix(position);

// After:
if (headingDelta >= kHeadingThreshold || speed >= kSpeedGuard) {
  _acceptFix(position);
}
```

The exact restructuring depends on the surrounding logic; preserve all existing acceptance paths (distance filter, time interval) unchanged.

## Acceptance Criteria

- [ ] Building with `flutter build apk --release` and hiking a straight path results in measurably fewer accepted GPS fixes compared to before the fix (verifiable via debug logging of accepted-fix counts).
- [ ] The heading-change gate correctly rejects fixes during straight-line walking (manual test: walk 100 m in a straight line; accepted fix count is less than `distance / 1 m`).
- [ ] Switchbacks and turns still result in dense fix capture (manual test: heading changes of > 10° produce accepted fixes).
- [ ] `flutter analyze` reports zero issues.
- [ ] No `assert` wraps the heading-gate logic in the final implementation.
