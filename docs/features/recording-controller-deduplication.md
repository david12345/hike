# recording-controller-deduplication.md

## User Story

As a developer maintaining the Hike app, I want the pedometer and checkpoint-timer setup code to appear in exactly one place, so that future changes to those subsystems only need to be made once.

## Background / Problem

Analysis report item **M2**.

`lib/services/hike_recording_controller.dart` contains two identical code blocks:

1. **Pedometer subscription setup** — approximately 18 lines (lines 350–366 in `startRecording()` and lines 529–545 in `resumeFromRecord()`). Both blocks set up the step counter stream, handle availability checks, and register the `onError` callback.
2. **Checkpoint timer setup** — approximately 7 lines (lines 368–374 in `startRecording()` and lines 547–553 in `resumeFromRecord()`). Both blocks create the `Timer.periodic` for checkpoint saves.

Copy-pasted logic means a bug fix or enhancement (e.g. adding a `debugPrint` from `silent-catch-logging.md`) must be applied twice or will silently diverge.

## Requirements

1. Extract the pedometer subscription setup into a private method `_startPedometerSubscription()` that contains the full subscription logic exactly once.
2. Extract the checkpoint timer setup into a private method `_startCheckpointTimer()`.
3. Both `startRecording()` and `resumeFromRecord()` call these private methods instead of containing the inline blocks.
4. The extracted methods must have identical observable behaviour to the current duplicated blocks — no logic changes.
5. The private methods must be documented with a brief comment explaining their purpose.

## Non-Goals

- Changing the pedometer logic, step-counting algorithm, or checkpoint save interval.
- Extracting these methods into separate classes (that is covered by other specs like `compass-manager-extraction.md`).
- Adding new tests in this PR (covered by `unit-tests-pure-dart.md`).

## Design / Implementation Notes

**Files to touch:**
- `lib/services/hike_recording_controller.dart` only.

**Sketch:**

```dart
/// Sets up the pedometer stream subscription.
/// Call from both [startRecording] and [resumeFromRecord].
void _startPedometerSubscription() {
  // ... existing 18-line block ...
}

/// Starts the checkpoint save timer.
/// Call from both [startRecording] and [resumeFromRecord].
void _startCheckpointTimer() {
  // ... existing 7-line block ...
}
```

After extraction, `startRecording()` and `resumeFromRecord()` each call `_startPedometerSubscription()` and `_startCheckpointTimer()` where the duplicated blocks previously appeared.

## Acceptance Criteria

- [ ] `_startPedometerSubscription()` and `_startCheckpointTimer()` exist as private methods in `HikeRecordingController`.
- [ ] The duplicated inline blocks are removed from both `startRecording()` and `resumeFromRecord()`.
- [ ] A diff of the two original blocks confirms they were truly identical (or any legitimate difference is preserved and documented).
- [ ] Recording and resuming from a crash-recovered record both correctly start the pedometer and checkpoint timer.
- [ ] `flutter analyze` reports zero issues.
