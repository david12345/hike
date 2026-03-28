# Hike App — Full Analysis Report

> Generated: 2026-03-28
> Version analysed: 1.0.16+17
> Reviewers: flutter-architect · flutter-code-quality · flutter-performance

---

## Summary

| Dimension | Score | Notes |
|-----------|-------|-------|
| Architecture | 6/10 | Near-MVVM applied inconsistently; good ViewModel in `HikeRecordingController` but screens own too much logic |
| Code Quality | 8/10 | Zero `dart analyze` issues; clean constants; granular `ValueNotifier` subsystems; two 1 000-line files need splitting |
| Performance | 6/10 | Solid GPS single-stream design; analytics computation blocks UI thread; 1 m GPS filter drains battery on long hikes |
| **Overall** | **7/10** | Well-engineered personal project with clear attention to lifecycle, offline, and battery. The gaps are known patterns that compound as the hike log grows. |

**Architecture maturity:** Service-layer MVVM, inconsistently applied. The Track + Map screens are nearly pure Views. The Log, Analytics, and Trails screens mix UI with preference-persistence business logic.

---

## Critical Issues

### C1 — Analytics computation blocks the UI thread on every hike save

**File:** `lib/screens/analytics_screen.dart:192–198`
**Risk:** Dropped frames / ANR on devices with large hike logs.

`HikeService.getAll()`, `_applyFilter()`, and `AnalyticsService.compute()` all run synchronously inside a `ListenableBuilder` builder that fires on every `HikeService.version` increment (i.e. every time a hike is saved, even from another tab). `AnalyticsService.compute()` performs O(N log N) work: multiple O(N) passes plus a sort for streak calculation. For 500 hikes this is measurable jank on mid-range Android.

**Fix:** Wrap `AnalyticsService.compute()` in a `compute()` isolate call, or introduce an `AnalyticsViewModel` that caches the result and only recomputes when the version or filter changes.

---

### C2 — Parallel lat/lon arrays can have a length mismatch after a crash

**File:** `lib/models/hike_record.dart:5–9`
**Risk:** `IndexError` crash on `HikeDetailScreen` if the Hive box is inconsistent.

`latitudes` and `longitudes` are stored as independent `List<double>` fields. Hive box writes are not transactional. A crash between the two writes leaves them at different lengths. `HikeDetailScreen.initState()` uses `latitudes.length` without verifying it matches `longitudes.length`.

**Fix:** Add a length-parity guard in `HikeDetailScreen.initState()`: if `latitudes.length != longitudes.length`, truncate to `min(...)` and log a warning.

---

### C3 — Heading-change gate is disabled in release builds

**File:** `lib/services/tracking_state.dart:350–361`
**Risk:** The 1 m / 2 s GPS density intended for switchback capture is completely unguarded in production.

The heading-change gate (intended to selectively accept fixes based on direction change, reducing battery drain on straight sections) is wrapped in an `assert` block. `assert` is a no-op in release builds. All fixes are unconditionally accepted via `_acceptFix` at line 361, meaning the GPS chip fires at near-maximum rate for the entire hike regardless of trail shape.

**Fix:** Move the heading-change guard out of the `assert` block so it runs in release builds.

---

## High Priority Improvements

### H1 — `AnalyticsScreen` and `TrailsScreen` own too much business logic

**Files:** `lib/screens/analytics_screen.dart`, `lib/screens/trails_screen.dart`

- `AnalyticsScreen` owns filter state (`_activePreset`, `_customRange`), `SharedPreferences` I/O, and full analytics recomputation — all inside widget `State`. This cannot be unit-tested without a widget test.
- `TrailsScreen` (1 015 lines) performs platform I/O directly in the widget: file picker, ZIP creation, share sheet, `DeviceInfoPlugin` SDK check, and permission negotiation. This is 150+ lines of business logic with no testable seam.

**Fix (H1a):** Extract an `AnalyticsViewModel` (`ChangeNotifier`) that owns the filter state and caches `AnalyticsStats`. The screen becomes a pure View.

**Fix (H1b):** Extract a `TrailsImportExportService` that owns `_importFile`, `_exportTrails`, and `_saveTrailsToDevice`. Move the `DeviceInfoPlugin` SDK check into this service.

---

### H2 — `SharedPreferences` I/O scattered across three screens

**Files:** `lib/screens/log_screen.dart:27–39`, `lib/screens/analytics_screen.dart:105–156`, `lib/screens/trails_screen.dart:82–93`

Each screen calls `SharedPreferences.getInstance()` independently in `initState`, creating async state at the widget layer and duplicating the load/save pattern.

**Fix:** Introduce a `UserPreferencesService` (following the `TilePreferenceService` pattern) that exposes `ValueNotifier` fields for each preference and is initialised once at app startup in `main.dart`.

---

### H3 — Weather timer fires during background GPS recording

**File:** `lib/services/hike_recording_controller.dart:177–183`
**Risk:** Up to 72 unnecessary HTTP requests during a 6-hour hike with the screen off.

The `Timer.periodic` for weather fetches runs on the main isolate continuously, including when the app is backgrounded. Weather data is not displayed when the screen is off.

**Fix:** Add an `AppLifecycleState` check in the weather timer callback: skip the fetch when `AppLifecycleState.paused` or `hidden`.

---

### H4 — Ambient GPS stream stays active when app is backgrounded without recording

**File:** `lib/services/tracking_state.dart:260–268`

The ambient stream (50 m filter, medium accuracy) runs continuously even when the user has backgrounded the app between hikes, keeping the GPS chip awake unnecessarily.

**Fix:** Add a `WidgetsBindingObserver` to `TrackingState` that pauses the ambient stream on `AppLifecycleState.paused` and resumes on `AppLifecycleState.resumed` (when not actively recording).

---

### H5 — `segmentsFromPoints()` not cached — called at GPS polling frequency on `MapScreen`

**Files:** `lib/screens/map_screen.dart:109`, `lib/screens/hike_detail_screen.dart:113`

`segmentsFromPoints()` iterates the full point list on every GPS fix inside the `ListenableBuilder`. On `HikeDetailScreen` the route never changes after `initState()` but segments are still recomputed on every parent rebuild.

**Fix (map):** Cache the segments list as a `late final` field in `HikeDetailScreen.initState()`. For `MapScreen`, consider computing segments inside `_onTrackingChanged` and storing the result in a field rather than recomputing in `build()`.

---

### H6 — Several `catch` blocks silently swallow errors

**Files:**
- `lib/screens/trails_screen.dart:211–214` — `FormatException` on import
- `lib/services/hike_recording_controller.dart:256–259` — pedometer probe
- `lib/services/hike_recording_controller.dart:362–365, 541–544` — pedometer `onError`
- `lib/services/hike_recording_controller.dart:447–449` — foreground service stop

**Fix:** Add `debugPrint` (minimum) to each catch block. The pedometer mis-cache case is especially important: a false-negative persisted to `SharedPreferences` silently disables step counting for the lifetime of the install.

---

### H7 — Stale CLAUDE.md note about `LogScreenState` being public

**File:** `CLAUDE.md` (Important Implementation Notes section)

The note says `LogScreenState` is intentionally public, but the class is `_LogScreenState` (private). The `GlobalKey` pattern was replaced by `ValueNotifier` in v1.26.0. The note is misleading.

**Fix:** Remove the `LogScreenState is public` note from CLAUDE.md.

---

## Medium Priority Improvements

### M1 — `HikeRecordingController` is a God class (600 lines, 5 responsibilities)

**File:** `lib/services/hike_recording_controller.dart`

Manages compass, pedometer, weather polling, GPS recording lifecycle, foreground service, checkpoint persistence, and crash recovery — all in one class.

**Incremental fix:** Extract `CompassManager` (pause/resume, heading `ValueNotifier`) and `WeatherPoller` (timer, fetch guard, `WeatherData` `ValueNotifier`) as standalone services. The controller becomes a thin orchestrator, dropping from ~600 to ~300 lines. This also eliminates the `pauseCompass()`/`resumeCompass()` calls from `_HomePageState`.

---

### M2 — Duplicated code in `HikeRecordingController`

**File:** `lib/services/hike_recording_controller.dart`

- Pedometer subscription setup copy-pasted between `startRecording()` (lines 350–366) and `resumeFromRecord()` (lines 529–545): ~18 identical lines.
- Checkpoint timer setup duplicated at lines 368–374 and 547–553.

**Fix:** Extract `_startPedometerSubscription()` and `_startCheckpointTimer()` private methods.

---

### M3 — `TrackScreen` bypasses `HikeRecordingController` to access `TrackingState` directly

**File:** `lib/screens/track_screen.dart:151, 239`

Inside `ValueListenableBuilder` callbacks for `positionNotifier`, the screen reads `TrackingState.instance.ambientAltitude` and `TrackingState.instance.ambientSpeed` directly, bypassing the ValueNotifier contract.

**Fix:** Add `altitudeNotifier` and `speedNotifier` (`ValueNotifier<double>`) to `HikeRecordingController`, populated in `_onTrackingChanged`. `TrackScreen` then has a single declared dependency.

---

### M4 — `pointCount` computed in `HikeDetailScreen.build()` at O(N)

**File:** `lib/screens/hike_detail_screen.dart:76–78`

```dart
final pointCount = widget.hike.latitudes.where((lat) => !lat.isNaN).length;
```

Filters the full latitudes list on every `build()` call. `_route` and `_realPoints` are already cached as `late final` in `initState()`.

**Fix:** Cache `pointCount` in `initState()` as a `late final int`.

---

### M5 — `_kBarColor` duplicates the theme seed colour

**File:** `lib/screens/analytics_screen.dart:686`

`const _kBarColor = Color(0xFF2E7D32)` is the same value as `ColorScheme.fromSeed(seedColor: Color(0xFF2E7D32))` in `main.dart`.

**Fix:** Define `kBrandGreen = Color(0xFF2E7D32)` in `constants.dart` and reference it in both places.

---

### M6 — Two 1 000-line screen files need decomposition

**Files:** `lib/screens/analytics_screen.dart` (1 022 lines), `lib/screens/trails_screen.dart` (1 015 lines)

`analytics_screen.dart` contains 13 private widget classes including three chart widgets with 60–80 lines of nested `BarChartData` each.

`trails_screen.dart` has a 200-line inline card builder and a 110-line `_TrailPreviewPanel.build`.

**Fix:**
- Move chart widgets to `lib/widgets/analytics_charts.dart`
- Extract `_TrailCard` from `trails_screen.dart`'s `itemBuilder`
- Extract `_HikeStatsSheet` from `hike_detail_screen.dart`'s `DraggableScrollableSheet` builder

---

### M7 — `context` used after async gap without `mounted` check

**File:** `lib/screens/log_screen.dart:96–108`

`_delete()` calls `HikeService.delete(hike.id)` after `await showDialog(...)` without checking `if (!mounted) return`.

**Fix:** Add `if (!mounted) return;` after each `await` that is followed by a context use.

---

### M8 — No test coverage on critical paths

**File:** `test/widget_test.dart` (single boilerplate test)

Zero unit tests for GPS recording lifecycle, path simplification, checkpoint save/recovery, analytics aggregation, or GPX/KML parsing.

**Suggested first tests (all pure Dart, no Flutter deps):**
1. `path_simplifier_test.dart`
2. `analytics_service_test.dart`
3. `gpx_parser_test.dart` / `kml_parser_test.dart`

---

### M9 — Several packages are multiple major versions behind

**File:** `pubspec.yaml`

| Package | Current | Latest |
|---------|---------|--------|
| `flutter_map` | 7.0.2 | 8.2.2 |
| `fl_chart` | 0.70.0 | 1.2.x |
| `geolocator` | 13.x | 14.x |
| `flutter_foreground_task` | 8.x | 9.x |
| `file_picker` | 8.x | 10.x |
| `share_plus` | 10.x | 12.x |

`dio_cache_interceptor_db_store` is discontinued (tracked in deferred spec `tile-cache-store-migration.md`).

---

## Nice-to-Have Enhancements

### N1 — Proactive tile pre-fetch for imported trails

The tile cache is reactive (only caches tiles actually rendered on screen). A hiker browsing a trail at home will not have the closer zoom levels cached unless they manually zoom in. A bounding-box pre-fetch at zoom levels 12–16 for any loaded trail would significantly improve offline readiness in the field.

---

### N2 — Offline weather fallback

`WeatherService` has no offline fallback. Cache the last successful `WeatherData` to `SharedPreferences` and display it with a "last updated" label when the network is unavailable.

---

### N3 — Make `TrackingState` and `HikeService` injectable

`TrackingState.instance` is accessed directly in 4 files and `HikeService` uses only static methods. Injecting them as constructor parameters would unlock unit tests for the recording pipeline without a running GPS stack.

---

### N4 — Strengthen `analysis_options.yaml`

Add:
```yaml
- always_declare_return_types
- avoid_dynamic_calls
- cancel_subscriptions
- close_sinks
- use_super_parameters
- prefer_final_in_for_each
```

`avoid_dynamic_calls` is particularly valuable given the JSON parsing in `WeatherService`.

---

### N5 — Tile cache size limit

`DbCacheStore` has a 30-day TTL but no maximum size cap. A `maxSize` parameter (e.g. 500 MB) would prevent unbounded disk growth on devices with limited storage.

---

## Suggested Refactoring Plan

Ordered by impact-to-effort ratio. Each step is independent unless noted.

| # | Change | File(s) | Effort | Impact |
|---|--------|---------|--------|--------|
| 1 | Fix heading gate — move out of `assert` | `tracking_state.dart` | 15 min | 🔴 High — battery drain fix |
| 2 | Add `mounted` check in `_delete()` | `log_screen.dart` | 5 min | 🔴 High — async safety |
| 3 | Add `debugPrint` to all silent `catch` blocks | multiple | 30 min | 🔴 High — debugging |
| 4 | Cache `pointCount` + segments in `initState` | `hike_detail_screen.dart` | 15 min | 🟡 Medium |
| 5 | Add lat/lon length-parity guard | `hike_detail_screen.dart` | 10 min | 🔴 High — crash fix |
| 6 | Remove stale `LogScreenState` CLAUDE.md note | `CLAUDE.md` | 5 min | 🟢 Low |
| 7 | Extract `_startPedometerSubscription()` + `_startCheckpointTimer()` | `hike_recording_controller.dart` | 30 min | 🟡 Medium |
| 8 | Add `AppLifecycleState` check to weather timer | `hike_recording_controller.dart` | 30 min | 🔴 High — battery |
| 9 | Pause ambient GPS when backgrounded | `tracking_state.dart` | 1 h | 🔴 High — battery |
| 10 | Move `AnalyticsService.compute()` to isolate | `analytics_screen.dart` | 1 h | 🔴 High — jank fix |
| 11 | Introduce `UserPreferencesService` | new file + 3 screens | 2 h | 🟡 Medium |
| 12 | Extract chart widgets to `analytics_charts.dart` | `analytics_screen.dart` | 1 h | 🟡 Medium |
| 13 | Extract `_TrailCard` widget | `trails_screen.dart` | 1 h | 🟡 Medium |
| 14 | Add `altitudeNotifier`/`speedNotifier` to controller | `hike_recording_controller.dart` | 30 min | 🟡 Medium |
| 15 | Extract `TrailsImportExportService` | `trails_screen.dart` | 3 h | 🔴 High — architecture |
| 16 | Extract `CompassManager` + `WeatherPoller` | `hike_recording_controller.dart` | 3 h | 🟡 Medium |
| 17 | Add unit tests for parsers + analytics | `test/` | 2 h | 🔴 High — reliability |
| 18 | Structured dependency upgrade plan | `pubspec.yaml` | 4 h | 🟡 Medium |
