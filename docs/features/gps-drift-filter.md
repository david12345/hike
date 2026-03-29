# Feature Spec: GPS Stationary Drift Filter

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** `hike-recording-controller.md` (point appending lives in `_onRecordingPoint`)
**Related:** `gps-stationary-detection.md` (stream-frequency switching — orthogonal to this spec)

---

## User Story

As a hiker who stops at a viewpoint or trailhead, I want the app to suppress
GPS jitter points while I am standing still, so that my saved route does not
accumulate an ugly cluster of zigzag points at my rest stops and my recorded
distance accurately reflects how far I actually walked.

---

## Background / Problem

Consumer GPS chipsets produce fixes with a horizontal accuracy radius of
1–10 m even when the device is completely stationary. The `distanceFilter: 1`
setting in `LocationService.trackPosition()` is an OS/hardware hint, not a
guarantee — the Fused Location Provider on Android can and does deliver fixes
that have "moved" 1–3 m purely due to RF noise and multipath. With a 1 m
distance filter and a 2 s time interval, a 10-minute rest stop can generate
dozens of accepted fixes scattered in a small cluster.

### Downstream effects

1. **Distance inflation.** Each jitter step adds a few metres. Over a hike with
   multiple rest stops, this can add 50–200 m to the recorded distance.
2. **Polyline quality.** The saved route shows a dense zigzag cluster at every
   stop, making it harder to read the actual path of travel.
3. **Douglas-Peucker partial mitigation.** `path-simplification-dp.md`
   simplifies the route at save time with epsilon = 3 m, but simplification
   preserves the cluster "hull" — the boundary points are kept, leaving a
   visible blob.

### How this differs from `gps-stationary-detection.md`

`gps-stationary-detection.md` tackles power consumption by switching the
platform stream to a lower frequency (10 s interval) after 10 s of stationary
speed. The stream-frequency switch reduces the *volume* of incoming fixes but
does not guarantee zero jitter points: a 10 m `distanceFilter` still passes
fixes that have moved 2–10 m from the previous one due to noise.

This spec operates at the **application layer** inside
`HikeRecordingController._onRecordingPoint`, after the fix has already been
accepted by the platform stream and by `TrackingState`'s accuracy gate. It
answers: "is this fix part of a stationary cluster?" If so, it is suppressed
before being written to `_inFlight`.

The two specs are fully complementary and independently deployable:
- Stationary detection reduces chipset wake-ups (battery).
- Drift filter removes residual jitter from whatever fixes do arrive (quality).

---

## Proposed Design

### Algorithm: stationary window

Maintain a **stationary window** — a sliding buffer of the N most recently
accepted fixes. If all N fixes fall within a radius R of each other, the hiker
is considered stationary and new fixes are suppressed.

```
kDriftFilterWindowSize = 3   // fixes
kDriftFilterRadiusMetres = 8 // metres
```

These constants are placed in `lib/utils/constants.dart`.

#### Why N = 3

Three consecutive fixes within 8 m is an unambiguous stationary signal.
- Two fixes could be a very slow start of movement (0.5 m/s × 2 s = 1 m
  step, easily within 8 m twice).
- Three consecutive near-identical fixes within a 6-second window (3 × 2 s)
  are almost certainly noise.

A window of 3 also means the filter activates within 6 seconds of stopping,
which is fast enough to prevent meaningful jitter accumulation.

#### Why R = 8 m

- GPS jitter radius at good-sky locations is typically 2–5 m.
- 8 m provides margin for moderate-sky conditions (partial canopy) where jitter
  can reach 6–7 m without the fix failing the 30 m accuracy gate.
- 8 m is below the 10 m `distanceFilter` used in stationary mode
  (`gps-stationary-detection.md`), so the filter catches jitter at both stream
  frequencies.

Both constants are named and easily tunable.

### State: centroid and window buffer

Add three private fields to `HikeRecordingController`:

```dart
/// Buffer of the N most recently accepted fixes (lat/lon only).
///
/// Used by the stationary drift filter to decide whether an incoming fix
/// is part of a stationary jitter cluster.
final List<({double lat, double lon})> _driftWindow = [];

/// Whether the drift filter is currently in suppression mode.
bool _driftSuppressing = false;

/// The centroid of the current drift window, updated on every window append.
/// Null when [_driftWindow] is empty.
({double lat, double lon})? _driftCentroid;
```

### Integration point: `_onRecordingPoint`

The drift filter runs at the top of `_onRecordingPoint`, before the distance
accumulator and point-append logic. The existing method signature is unchanged:

```dart
void _onRecordingPoint(double lat, double lon) {
  if (_inFlight == null) return;

  // --- Stationary drift filter ---
  if (_applyDriftFilter(lat, lon)) return; // suppressed
  // --- end drift filter ---

  if (_inFlight!.latitudes.isNotEmpty) {
    final dist = LocationService.distanceBetween(
      _inFlight!.latitudes.last,
      _inFlight!.longitudes.last,
      lat, lon,
    );
    _inFlight!.distanceMeters += dist;
  }
  _inFlight!.latitudes.add(lat);
  _inFlight!.longitudes.add(lon);
  notifyListeners();
  // ... checkpoint save, notification update ...
}
```

### `_applyDriftFilter` logic

```
_applyDriftFilter(lat, lon) → bool (true = suppress this fix)

1. Append (lat, lon) to _driftWindow.
   Trim to kDriftFilterWindowSize entries (drop oldest if oversized).

2. If _driftWindow.length < kDriftFilterWindowSize:
   // Not enough history yet. Always record.
   _driftSuppressing = false
   return false

3. Compute the centroid of _driftWindow (arithmetic mean of lat, arithmetic
   mean of lon).
   Cache as _driftCentroid.

4. Compute the max distance from centroid to any fix in the window.
   Use LocationService.distanceBetween (Haversine).

5. If maxDist <= kDriftFilterRadiusMetres:
   // All window fixes are within R of each other — stationary cluster.
   _driftSuppressing = true
   return true  // suppress this fix

6. Else:
   // Fix has exited the stationary radius — movement detected.
   If _driftSuppressing was true:
     // This is the exit point — record it as the next route point.
     // _applyDriftFilter returns false so _onRecordingPoint records it.
   _driftSuppressing = false
   // Clear the window so the next N fixes start a fresh detection round.
   _driftWindow.clear()
   return false
```

The exit-point is automatically recorded because `_applyDriftFilter` returns
`false` for it. No separate handling is needed.

### First fix is always recorded

When `_driftWindow.length < kDriftFilterWindowSize` (the first N−1 fixes of
a session, or after a window clear), `_applyDriftFilter` returns `false`.
The very first fix of a recording session passes unconditionally.

### Elapsed time is unaffected

The drift filter operates only in `_onRecordingPoint`, which is called from the
recording-point broadcast stream. The elapsed timer (`_ElapsedTimeTile`) is
driven by `_inFlight.startTime` and `DateTime.now()`, completely independently.
Suppressing GPS points has no effect on the displayed elapsed time.

### Interaction with NaN gap detection

Gap detection in `TrackingState._acceptFix` fires when no accepted fix arrives
for > `kGapThresholdSeconds` (30 s). The drift filter runs inside
`HikeRecordingController._onRecordingPoint`, which is called by the
`recordingPoints` broadcast stream. `TrackingState._acceptFix` calls
`_recordingPointController.add(...)` before calling `addPoint(...)` — meaning
the broadcast event is emitted for every fix that passes the accuracy gate,
regardless of the drift filter.

The drift filter therefore operates on an **already gap-checked stream**. The
sequence is:
1. `TrackingState._onRecordingFix` — accuracy gate, adaptive buffer, gap check,
   heading gate, stationary mode switch.
2. `TrackingState._acceptFix` — gap marker insert if needed, then emit on
   `recordingPoints` stream.
3. `HikeRecordingController._onRecordingPoint` — drift filter, then append to
   `_inFlight`.

A NaN gap marker is never emitted on `recordingPoints` (gap markers are added
directly to `TrackingState._points`, not via the broadcast stream). So
`_onRecordingPoint` receives only real coordinate pairs. No NaN guard is
needed in the drift filter.

### Interaction with `distanceFilter: 1` on the location stream

`distanceFilter` is a hint to the OS Fused Location Provider. On Android, it
is honoured approximately: fixes that have moved less than 1 m from the
previous platform fix are filtered out before delivery. This already suppresses
the densest jitter.

The drift filter handles the residual: fixes that the OS considers "moved"
(1–8 m displacement) but that are part of a stationary cluster from the
hiker's perspective. The two mechanisms work at different layers and are not
redundant.

### Window reset on `stopRecording` and `startRecording`

`_driftWindow.clear()`, `_driftSuppressing = false`, `_driftCentroid = null`
must be called at the start of `startRecording()` and inside `stopRecording()`
before the state reset. They should also be called in `resumeFromRecord()` to
ensure crash-recovered sessions start with a clean window.

### Pure-Dart implementation, no new service

The entire filter is contained in three fields and one private method inside
`HikeRecordingController`. No new class, file, or service is introduced.

---

## Constants (`lib/utils/constants.dart`)

```dart
/// Number of consecutive GPS fixes that must all fall within
/// [kDriftFilterRadiusMetres] of each other before the hiker is considered
/// stationary for drift-filtering purposes.
///
/// 3 fixes at 2 s intervals = 6 seconds of stationary evidence.
const int kDriftFilterWindowSize = 3;

/// Radius (metres) within which consecutive fixes are treated as stationary
/// jitter rather than genuine movement.
///
/// 8 m covers GPS jitter at moderate-sky locations (partial canopy, urban
/// canyons) while remaining well below the 30 m accuracy gate threshold.
const double kDriftFilterRadiusMetres = 8.0;
```

---

## Files to Touch

| File | Change |
|------|--------|
| `lib/utils/constants.dart` | Add `kDriftFilterWindowSize` and `kDriftFilterRadiusMetres` constants |
| `lib/services/hike_recording_controller.dart` | Add `_driftWindow`, `_driftSuppressing`, `_driftCentroid` fields; add `_applyDriftFilter()` private method; call filter at top of `_onRecordingPoint`; reset fields in `startRecording()`, `stopRecording()`, `resumeFromRecord()` |

No changes to `TrackingState`, `HikeRecord`, `HikeService`, or any screen.
No new packages. No Hive schema change. No `build_runner` regeneration.

---

## Acceptance Criteria

- [ ] A 5-minute stationary test (device on a table, recording active) produces
      no more than `kDriftFilterWindowSize` points in the saved route.
- [ ] The DIST tile does not advance while the device is stationary (verified
      by watching the tile for 60 seconds with the device on a table).
- [ ] Walking away from a rest stop records the exit-point as the first new
      point (route does not skip the moment of departure).
- [ ] The TIME tile advances normally during a stationary period — the timer
      is unaffected by point suppression.
- [ ] The PTS tile shows a lower count after a rest stop compared to the
      current behaviour (regression test: record 2 minutes walking + 1 minute
      rest + 2 minutes walking; count PTS before and after this spec).
- [ ] A recording with no rest stops (continuous movement) produces the same
      number of route points as without this filter (filter does not suppress
      genuine movement).
- [ ] `flutter analyze` reports zero issues.

---

## Acceptance Criteria — Edge Cases

- [ ] The very first GPS fix of a recording session is always recorded
      (filter returns false when window is underfull).
- [ ] Slow walking at 0.3 m/s over 10 seconds (total movement 3 m, within 8 m
      radius) correctly suppresses intermediate fixes but records the start
      and the point that exits the window.
- [ ] Recording resumed after crash recovery (`resumeFromRecord`) starts with
      a clean drift window — stale window state from a previous session is
      not carried over.
- [ ] Pausing and resuming recording (if `recording-pause-resume.md` is
      implemented) clears the drift window on resume so the first post-pause
      fix is always recorded.

---

## Non-Functional Requirements

- **NF1 — No new packages.** Pure-Dart implementation.
- **NF2 — O(N) space.** Window buffer is bounded to `kDriftFilterWindowSize`
  entries (currently 3). Memory impact is negligible.
- **NF3 — O(N) per fix.** The centroid and max-distance computation iterate
  over at most 3 entries per incoming fix. No performance impact at normal GPS
  rates (0.5 Hz in stationary mode, 0.5 Hz in moving mode with heading gate).
- **NF4 — No data loss.** Suppressed points are simply not appended to
  `_inFlight`. The checkpoint timer and Hive save are unaffected.

---

## Trade-offs and Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Slow walking on a tight switchback suppressed as "stationary" | Low | Short section of route missing | kDriftFilterRadiusMetres = 8 m is large relative to 1–2 m/s walking speed; 8 m in 6 s = 1.3 m/s threshold effectively | Reduce radius if needed |
| Window does not clear after long stationary period — first movement fix suppressed | Not possible | — | Step 6 of the algorithm clears `_driftWindow` on the first fix that exits the radius |
| Interaction with Douglas-Peucker simplification at save time | None | — | Simplification runs on the already-filtered `_inFlight` point list; fewer input points means faster and equally accurate simplification |
| Different behaviour in stationary stream mode vs. moving mode | None | — | Filter is agnostic to stream frequency; it operates on whatever fixes arrive via `recordingPoints` |
