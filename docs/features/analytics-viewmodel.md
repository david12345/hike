# analytics-viewmodel.md

## User Story

As a developer maintaining the Hike app, I want the Analytics screen's filter state and computation logic to live in a dedicated ViewModel, so that the screen is a pure View that is easy to read and the business logic can be unit-tested without a widget tree.

## Background / Problem

Analysis report item **H1a**.

`lib/screens/analytics_screen.dart` (1 022 lines) currently owns filter state (`_activePreset`, `_customRange`), `SharedPreferences` I/O (reading and writing the persisted filter), and the full `AnalyticsService.compute()` call — all inside widget `State`. This logic cannot be unit-tested without spinning up a widget test. It also means the `ListenableBuilder` that drives analytics recomputation rebuilds the entire screen widget subtree.

## Requirements

1. Create `lib/viewmodels/analytics_viewmodel.dart` containing a `AnalyticsViewModel extends ChangeNotifier`.
2. `AnalyticsViewModel` owns:
   - `FilterPreset activePreset` (default: all-time or last 12 months, matching current behaviour).
   - `DateTimeRange? customRange` (non-null only when preset is `custom`).
   - `AnalyticsStats? stats` — the cached result of the last successful computation.
   - `bool isLoading` — true while the isolate computation is running.
   - `String? errorMessage` — set on isolate error, cleared on next successful compute.
3. `AnalyticsViewModel.init()` is an async method that reads the persisted filter from `UserPreferencesService` (see `user-preferences-service.md`) or `SharedPreferences` directly, then triggers an initial compute.
4. `AnalyticsViewModel.setPreset(FilterPreset)` and `setCustomRange(DateTimeRange)` update state and trigger a recompute.
5. Recomputation uses `compute()` isolate as specified in `analytics-isolate-compute.md`.
6. `AnalyticsViewModel` listens to `HikeService.version` to auto-recompute when hikes are added or deleted.
7. `AnalyticsScreen` is refactored to read exclusively from the `AnalyticsViewModel` exposed via a `ListenableBuilder` or `ChangeNotifierProvider`.
8. `AnalyticsScreen` must contain no `SharedPreferences` calls.
9. `AnalyticsViewModel` is instantiated once and kept alive (e.g. as a `late final` in `_HomePageState` or via a service locator) so cached stats survive tab switches.

## Non-Goals

- Introducing a full dependency-injection framework (GetIt, Riverpod) — a simple field on `_HomePageState` is sufficient.
- Migrating other screens to a ViewModel pattern in the same PR.
- Persisting computed stats to disk.

## Design / Implementation Notes

**New file:** `lib/viewmodels/analytics_viewmodel.dart`

**Files to touch:**
- `lib/screens/analytics_screen.dart` — strip business logic; read from `AnalyticsViewModel`.
- `lib/main.dart` — instantiate `AnalyticsViewModel` alongside `HikeRecordingController`.

**Directory convention:** create `lib/viewmodels/` if it does not exist.

**Relationship with `analytics-isolate-compute.md`:** that spec defines how the isolate call is structured. This spec defines the ViewModel wrapper that owns the call. Both can be implemented together.

## Acceptance Criteria

- [ ] `lib/viewmodels/analytics_viewmodel.dart` exists and contains `AnalyticsViewModel`.
- [ ] `AnalyticsScreen` contains no direct `SharedPreferences.getInstance()` calls.
- [ ] `AnalyticsScreen` contains no `AnalyticsService.compute()` calls — all analytics work is delegated to the ViewModel.
- [ ] `AnalyticsViewModel` can be instantiated and exercised in a plain Dart unit test without a Flutter widget tree.
- [ ] Switching away from and back to the Analytics tab does not re-trigger computation if the hike list has not changed.
- [ ] A loading indicator is shown while `isLoading == true`.
- [ ] `flutter analyze` reports zero issues.
