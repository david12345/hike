# injectable-services.md

## User Story

As a developer writing unit tests for the Hike app, I want to inject mock implementations of `TrackingState` and `HikeService` into the recording pipeline, so that I can test recording logic without a real GPS stack or a real Hive database.

## Background / Problem

Analysis report item **N3**.

`TrackingState.instance` is accessed directly (as a singleton) in four files. `HikeService` uses only static methods. Neither can be replaced with a test double without patching global state. This makes it impossible to write fast, isolated unit tests for `HikeRecordingController` — the most critical path in the app — without spinning up a device with GPS hardware or opening a real Hive box.

## Requirements

1. Define an abstract interface `ITrackingState` (or `TrackingStateBase`) that exposes the subset of `TrackingState` used by `HikeRecordingController` and `TrackScreen` (position stream, `isRecording`, `recordedPoints`, `ambientAltitude`, `ambientSpeed`).
2. `TrackingState` implements `ITrackingState`.
3. `HikeRecordingController` accepts an `ITrackingState` as a constructor parameter, defaulting to `TrackingState.instance` for production code.
4. Define an abstract interface `IHikeService` (or convert `HikeService` to an instance class) that exposes `save()`, `delete()`, `getAll()`, and `findUnfinished()`.
5. `HikeService` implements `IHikeService`.
6. `HikeRecordingController` accepts an `IHikeService` as a constructor parameter, defaulting to a real `HikeService` instance.
7. Existing call sites (`SplashScreen`, `main.dart`) continue to pass no arguments (defaults are used), preserving backward compatibility.
8. A `FakeTrackingState` and `FakeHikeService` test double are created in `test/fakes/` for use in unit tests.

## Non-Goals

- Migrating all singleton access across the entire app in one PR — focus only on `HikeRecordingController` as the primary beneficiary.
- Introducing a full DI framework (GetIt, injectable package).
- Making `TileCacheService` injectable.

## Design / Implementation Notes

**New files:**
- `lib/services/i_tracking_state.dart` — abstract interface.
- `lib/services/i_hike_service.dart` — abstract interface.
- `test/fakes/fake_tracking_state.dart`.
- `test/fakes/fake_hike_service.dart`.

**Files to touch:**
- `lib/services/tracking_state.dart` — add `implements ITrackingState`.
- `lib/services/hike_service.dart` — convert to instance class implementing `IHikeService`; preserve a `HikeService.instance` singleton for existing call sites.
- `lib/services/hike_recording_controller.dart` — update constructor signature.

**Constructor sketch:**
```dart
class HikeRecordingController extends ChangeNotifier {
  HikeRecordingController({
    ITrackingState? trackingState,
    IHikeService? hikeService,
  })  : _trackingState = trackingState ?? TrackingState.instance,
        _hikeService = hikeService ?? HikeService.instance;
}
```

**Relationship with `unit-tests-pure-dart.md`:** the fakes created here enable a future `hike_recording_controller_test.dart` that tests the full recording lifecycle.

## Acceptance Criteria

- [ ] `ITrackingState` and `IHikeService` abstract interfaces exist in `lib/services/`.
- [ ] `HikeRecordingController` can be instantiated with a `FakeTrackingState` and `FakeHikeService` in a plain Dart test.
- [ ] Existing production code that constructs `HikeRecordingController` without arguments continues to work.
- [ ] `flutter analyze` reports zero issues.
- [ ] A proof-of-concept test in `test/hike_recording_controller_test.dart` constructs the controller with fakes and calls `startRecording()` without throwing.
