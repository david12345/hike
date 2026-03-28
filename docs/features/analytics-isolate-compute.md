# analytics-isolate-compute.md

## User Story

As a hiker with a large hike log, I want the Analytics screen to remain smooth and responsive when I open it or save a new hike, so that the app does not stutter or freeze while computing statistics.

## Background / Problem

Analysis report item **C1**.

`AnalyticsService.compute()` is called synchronously inside a `ListenableBuilder` builder in `lib/screens/analytics_screen.dart` (lines 192–198). This builder fires on every increment of `HikeService.version`, which happens every time a hike is saved from any tab. `AnalyticsService.compute()` performs O(N log N) work: multiple O(N) passes over all hike records plus a sort for streak calculation. For 500 hikes on a mid-range Android device this work is measurable on the main isolate and can cause dropped frames or an ANR dialog.

## Requirements

1. `AnalyticsService.compute()` must be called via Flutter's `compute()` top-level function so that the work runs on a background Dart isolate.
2. The `AnalyticsViewModel` (see `analytics-viewmodel.md`) or the screen must display a loading indicator while the isolate computation is in progress.
3. If a new computation is triggered while one is already running (e.g. rapid version increments), the in-flight computation must be superseded — only the most recent result is applied.
4. The main isolate must not block waiting for the isolate result; the result is delivered via a `Future` callback that calls `setState` / `notifyListeners`.
5. `AnalyticsService` must remain a pure-Dart class with no Flutter dependencies so it can be called from `compute()` without restrictions.
6. Error handling: if the isolate throws, log the error with `debugPrint` and fall back to displaying the previous cached result (or an empty state with an error message).

## Non-Goals

- Replacing `compute()` with a long-lived `Isolate` or `IsolateNameServer` — the simpler `compute()` call is sufficient.
- Persisting analytics results to disk as a cache — that is a separate optimisation.
- Changing the `AnalyticsStats` data model.

## Design / Implementation Notes

**Files to touch:**
- `lib/services/analytics_service.dart` — verify it has no Flutter imports; add a top-level function wrapper suitable for `compute()`.
- `lib/screens/analytics_screen.dart` (or `lib/viewmodels/analytics_viewmodel.dart` once extracted) — replace synchronous call with `await compute(_runAnalytics, input)`.

**Key decisions:**

`compute()` requires the entry point to be a top-level or static function. Introduce a top-level function:

```dart
AnalyticsStats _runAnalytics(_AnalyticsInput input) {
  return AnalyticsService.compute(input.records, input.filter);
}
```

where `_AnalyticsInput` is a simple data class holding the list of `HikeRecord` snapshots and the active filter. Both must be sendable across isolate boundaries (plain Dart objects — no `ChangeNotifier`, no `LatLng` wrappers that use non-sendable types).

Use a cancellation flag (simple `int _computeGeneration` counter) to discard results from superseded computations:

```dart
int _generation = 0;

Future<void> _recompute() async {
  final gen = ++_generation;
  final stats = await compute(_runAnalytics, input);
  if (gen != _generation) return; // superseded
  setState(() => _stats = stats);
}
```

## Acceptance Criteria

- [ ] Opening the Analytics screen with 200+ hike records does not cause a visible frame drop (verified with Flutter DevTools timeline — no frame > 16 ms on the main thread during computation).
- [ ] A loading spinner or skeleton is shown while the isolate is running.
- [ ] Saving a hike on the Track tab while the Analytics tab is visible triggers a recompute without freezing any other tab.
- [ ] If two recomputes are triggered in quick succession, only the last result is applied (no stale data flash).
- [ ] `flutter analyze` reports zero issues after the change.
- [ ] `AnalyticsService` has no Flutter imports and can be instantiated in a plain Dart unit test.
