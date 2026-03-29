# Feature Spec: Pause/Resume Recording

**Status:** Proposed
**Date:** 2026-03-29
**Depends on:** `hike-recording-controller.md` (HikeRecordingController owns recording lifecycle), `gps-checkpoint-saves.md` (checkpoint saves must fire on pause)

---

## User Story

As a hiker who takes rest breaks during a long hike, I want to pause my
recording while I stop for lunch or a photo, so that the elapsed timer freezes
and no spurious GPS drift points accumulate while I am standing still — without
losing the route I have recorded so far.

---

## Background / Problem

The Track screen currently offers only two states: recording and idle. Pressing
"Stop & Save" ends the hike permanently and persists the record. There is no
way to freeze the session without ending it.

When a hiker rests:
- The elapsed timer (`_ElapsedTimeTile`) keeps incrementing, inflating the
  recorded duration.
- GPS fixes continue to arrive and are appended to the in-flight record,
  inflating distance and creating jitter clusters at the rest location (even
  after `gps-stationary-detection.md` reduces their frequency, some fixes still
  get through).
- The foreground notification keeps showing "Recording" with a moving timer,
  which is confusing when the hiker has consciously stopped.

---

## Proposed Design

### State model

Add a `bool _isPaused` flag to `HikeRecordingController`. The observable
recording state becomes a three-way combination:

| `_isRecording` | `_isPaused` | Meaning |
|---------------|-------------|---------|
| `false`       | `false`     | Idle — no session in progress |
| `true`        | `false`     | Active recording |
| `true`        | `true`      | Session paused — timer frozen, GPS suppressed |

A dedicated public getter exposes the flag:

```dart
/// Whether the current recording session is paused.
///
/// Always false when [isRecording] is false.
bool get isPaused => _isPaused;
```

No new enum is introduced. The `_isRecording` / `_isPaused` pair is sufficient
and avoids changing the public API surface for `isRecording` which is used across
several screens.

### New methods on `HikeRecordingController`

#### `pauseRecording()`

```dart
/// Pauses the active recording session.
///
/// - Cancels the GPS recording stream subscription so no new points are
///   accepted. The subscription is stored for cancellation; the stream is
///   not paused — it is cancelled entirely to guarantee zero callbacks.
/// - Cancels the checkpoint timer; fires a final checkpoint save immediately.
/// - Cancels the pedometer subscription.
/// - Records the wall time of the pause as [_pauseStartedAt] so active
///   duration can be computed correctly on resume.
/// - Updates the foreground notification to "Paused".
/// - Does NOT stop the foreground service itself (keeps the notification
///   visible and prevents Android from killing the process).
/// - Calls [notifyListeners].
///
/// No-op if [isRecording] is false or [isPaused] is already true.
void pauseRecording()
```

#### `resumeRecording({required void Function(String) onError})`

```dart
/// Resumes a paused recording session.
///
/// - Re-subscribes to [TrackingState.instance.recordingPoints] (the existing
///   broadcast stream remains open during the pause).
/// - Restarts the pedometer subscription with the current sensor baseline
///   preserved (steps are not reset).
/// - Restarts the checkpoint timer.
/// - Advances [_inFlight.startTime] forward by the paused duration so that
///   [_ElapsedTimeTile] reflects only active hiking time.
///   Specifically: _inFlight!.startTime += (DateTime.now() - _pauseStartedAt!)
/// - Updates the foreground notification to "Recording".
/// - Sets [_isPaused = false] and calls [notifyListeners].
///
/// No-op if [isPaused] is false.
Future<void> resumeRecording({required void Function(String) onError})
```

### Timer freezing

`_ElapsedTimeTile` computes elapsed time as
`DateTime.now().difference(widget.startTime)`. Advancing `startTime` by the
paused duration is the simplest way to freeze the displayed elapsed time without
adding any new fields to `HikeRecord` or `_ElapsedTimeTile`.

When the hiker pauses at T=00:30:00 and resumes 10 minutes later,
`startTime` is shifted forward 10 minutes so the tile immediately shows
00:30:00 again and continues from there.

`_inFlight.startTime` is already persisted in Hive checkpoints. After the
`startTime` shift, the next checkpoint save writes the corrected start time,
so crash recovery also displays the correct active duration.

### GPS stream management during pause

`_recordingPointSub` (the subscription to `TrackingState.instance.recordingPoints`)
is **cancelled** on pause, not paused. This is intentional:

- `TrackingState` continues to receive GPS fixes from the platform (the
  underlying location stream is owned by `TrackingState`, not by
  `HikeRecordingController`). Ambient fixes keep the map dot moving correctly.
- `HikeRecordingController._onRecordingPoint` will not be called while the
  subscription is cancelled, so no points are appended and distance does not
  accumulate.
- On resume, a new subscription is created with
  `TrackingState.instance.recordingPoints.listen(...)`.

This is safe because `TrackingState._recordingPointController` is a broadcast
stream — multiple subscriptions (and sequential subscribe/cancel cycles) are
supported.

Do not call `TrackingState.instance.stopRecording()` on pause. The recording
stream inside `TrackingState` must stay active so:
1. The map dot continues to update.
2. The foreground service stays alive.
3. `TrackingState._points` continues to receive points for the live map
   polyline.

Points added to `TrackingState._points` during a pause are visible on the live
Map screen (they keep the map dot current) but are NOT appended to
`_inFlight` (because `_recordingPointSub` is cancelled). This is the correct
behaviour: the live map always shows where you are; the recorded hike only
captures points while actively recording.

### Checkpoint save on pause

Before cancelling the subscription in `pauseRecording()`:
1. Cancel the periodic checkpoint timer.
2. Await `_saveCheckpoint()` once, synchronously in the pause flow, so the
   current in-flight state is persisted before GPS delivery stops.
3. Reset `_pointsSinceCheckpoint = 0`.

### Pedometer during pause

The pedometer subscription is cancelled on pause. Steps taken during a rest
break should not count toward the hike total. On resume:
- `_startPedometerSubscription()` is called (the existing M2 helper).
- `_stepBaselineSet` is reset to `false` and `_stepBaseline` is reset to `0`
  so the first new event after resume establishes the new baseline. This
  correctly excludes steps taken during the rest break.

### Foreground notification

`ForegroundTrackingService` gains a new static method:

```dart
/// Updates the notification to show a paused state.
///
/// Displays the elapsed active time at the moment of pause (frozen).
static Future<void> pauseNotification({
  required Duration activeElapsed,
  required double distanceMeters,
}) async {
  final h = activeElapsed.inHours.toString().padLeft(2, '0');
  final m = (activeElapsed.inMinutes % 60).toString().padLeft(2, '0');
  final s = (activeElapsed.inSeconds % 60).toString().padLeft(2, '0');
  final distText = distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
      : '${distanceMeters.toStringAsFixed(0)} m';
  await FlutterForegroundTask.updateService(
    notificationTitle: 'Hike — Paused',
    notificationText: '$h:$m:$s — $distText',
  );
}
```

On resume, the existing `updateNotification` method is used to restore the
"Recording" title. The throttle (`_lastNotificationUpdate`) is reset to null on
pause so the first resume update goes through immediately.

### Track screen UI

Zone 3 (the Start/Stop button row) is rebuilt via `ListenableBuilder` on
`_controller`. When `isRecording && !isPaused`, show two buttons side by side:

```
[ ⏸  Pause  ]   [ ⏹  Stop & Save ]
```

When `isRecording && isPaused`, show:

```
[ ▶  Resume ]   [ ⏹  Stop & Save ]
```

When `!isRecording`, show the existing full-width Start Hike button.

Button layout: `Row` with two `Expanded` children, separated by a fixed 8 dp
gap. Each button uses `ElevatedButton.icon`. The Pause/Resume button uses
`Colors.orange` background; the Stop button retains `Colors.red`. Both are
64 dp tall to match the current button height.

The red "Recording..." dot indicator below the buttons is shown when
`isRecording && !isPaused`. When paused, replace it with an amber
"Paused" indicator using the same dot layout:

```dart
Container(
  color: Colors.amber,
  // ...
),
const SizedBox(width: 8),
const Text('Paused', style: TextStyle(color: Colors.amber)),
```

### `stopRecording()` when paused

`stopRecording` must work correctly when called from a paused state. Before the
existing save logic, add:

```dart
if (_isPaused) {
  _isPaused = false;
  // _recordingPointSub is already cancelled — nothing to cancel here.
  // _checkpointTimer is already cancelled — nothing to cancel here.
}
```

The rest of `stopRecording()` (pedometer cancel, foreground service stop, path
simplification, Hive save, state reset) proceeds identically.

### Crash recovery path when paused

When the app is paused-and-killed, the Hive checkpoint record has:
- `endTime == null` (not yet stopped) — triggers crash recovery on next launch.
- `startTime` = the corrected start time (shifted forward by any prior pauses).

The crash recovery dialog (`SplashScreen`) detects `endTime == null` and
offers "Resume" or "Discard". Pressing "Resume" calls
`controller.resumeFromRecord(record)`, which restores active recording. There
is no need to restore the `_isPaused` state — a pause is ephemeral. After crash
recovery the hike resumes in the active-recording state, which is the safer
default.

### Interaction with gap detection

When the hiker pauses for an extended period and then resumes, the gap detector
in `TrackingState._acceptFix` compares the new fix time against
`_lastAcceptedFixAt`. A long pause will exceed `kGapThresholdSeconds` (30 s)
and insert a NaN gap marker into `TrackingState._points` on resume. This is
the correct behaviour — the live map polyline will show a break during the rest
stop — but the NaN sentinel is not added to `_inFlight` (because
`_recordingPointSub` was cancelled during the pause). The gap marker therefore
appears on the live Map screen but not in the saved `HikeRecord`. This is
intentional: a deliberate user pause is not a tracking gap.

To prevent a gap marker from being inserted on the resume fix after a long
pause, `HikeRecordingController.resumeRecording()` should call a new method on
`TrackingState`:

```dart
/// Resets the last-accepted-fix timestamp so the next fix does not
/// trigger a gap marker after a deliberate user pause.
///
/// Call immediately before re-subscribing to [recordingPoints] in
/// [HikeRecordingController.resumeRecording].
void resetGapTimer() {
  _lastAcceptedFixAt = DateTime.now();
  _gapJustInserted = false;
}
```

This is the only new public method added to `TrackingState`.

---

## Out of Scope

- Mid-pause NaN gap insertion in the saved record (handled separately by the
  gap-detection spec; this spec explicitly resets the gap timer on resume).
- Pausing background GPS entirely during a user pause (the location stream
  continues running inside `TrackingState` to keep the map dot live).
- Auto-pause on detected stationarity (this spec is a manual user action).
- Pausing the weather polling timer during a user pause (weather data is useful
  even while resting).

---

## Files to Touch

| File | Change |
|------|--------|
| `lib/services/hike_recording_controller.dart` | Add `_isPaused`, `_pauseStartedAt`; add `isPaused` getter; add `pauseRecording()`, update `resumeRecording()`; update `stopRecording()` to handle paused state; update `_startPedometerSubscription` baseline reset |
| `lib/services/foreground_tracking_service.dart` | Add `pauseNotification()` static method |
| `lib/services/tracking_state.dart` | Add `resetGapTimer()` public method |
| `lib/screens/track_screen.dart` | Update Zone 3 button row: two-button layout when recording, Pause/Resume state toggle, amber Paused indicator |

No Hive schema change. No new packages. No `build_runner` regeneration.

---

## Acceptance Criteria

- [ ] Tapping Pause while recording freezes the TIME tile immediately.
- [ ] Tapping Pause while recording freezes the DIST tile immediately.
- [ ] No new GPS points are appended to the in-flight record while paused
      (PTS tile does not increment during a 60-second pause).
- [ ] The foreground notification shows "Hike — Paused" with the frozen elapsed
      time while paused.
- [ ] Tapping Resume restores the Recording state; TIME tile resumes from the
      frozen value (not from zero, not including the pause gap).
- [ ] Tapping Stop & Save while paused saves the record correctly; the detail
      screen shows only the active elapsed time and the pre-pause GPS points.
- [ ] Steps taken during a pause do not count toward the STEPS tile after resume.
- [ ] After a pause longer than 30 seconds, no NaN gap marker appears in the
      saved HikeRecord (the resetGapTimer call suppresses it).
- [ ] A NaN gap marker DOES appear in the live map polyline (MapScreen) when
      resuming after > 30 seconds paused — the map dot bridge is broken at the
      rest stop.
- [ ] Crashing while paused and restarting the app triggers crash recovery;
      resuming from recovery starts in active-recording state (not paused).
- [ ] `flutter analyze` reports zero issues.

---

## Acceptance Criteria — Edge Cases

- [ ] Calling `pauseRecording()` when already paused is a no-op (no double
      cancel of subscriptions, no second checkpoint save).
- [ ] Calling `stopRecording()` immediately after `pauseRecording()` with no
      `resumeRecording()` in between completes correctly and saves the record.
- [ ] Rapid Pause → Resume → Pause within 2 seconds does not cause subscription
      overlap or duplicate recording points.
- [ ] Pausing on the Track tab, switching to Map tab, and switching back shows
      the correct Paused button state.

---

## Non-Functional Requirements

- **NF1 — No new packages.** All changes are pure Dart/Flutter.
- **NF2 — No data loss.** A checkpoint save fires synchronously inside
  `pauseRecording()` before any subscriptions are cancelled.
- **NF3 — Battery neutral.** The GPS platform stream continues at the same rate
  during a pause (location authority remains with `TrackingState`). Battery
  savings from pausing come from the pedometer sensor, not the GPS chipset.
- **NF4 — No Hive schema change.** `startTime` adjustment is an in-memory
  mutation persisted as part of the normal checkpoint save.
