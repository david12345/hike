# Hike App — Full Analysis Report

**Version:** 1.0.26+27
**Date:** 2026-03-31
**Scope:** Architecture · Code Quality · Performance · Testing

---

## Summary

**Overall Health Score: 7.5 / 10**

The app is solid and well-structured. The GPS recording pipeline (`TrackingState` → `HikeRecordingController` → `TrackScreen`) is the strongest part: single GPS stream owner, granular `ValueNotifier` listeners, checkpoint saves, crash recovery, path simplification, and an incremental O(1) map update path. The analytics isolate, tile caching, foreground service, and localisation (pt/en) are all done correctly. `flutter analyze` is clean against a strict rule set.

The main weaknesses are **architectural inconsistency across screens** (only `TrackScreen` and `AnalyticsScreen` have proper ViewModels; `LogScreen`, `MapScreen`, and `TrailsScreen` still mix UI with business logic), **battery leaks** (wake lock and weather timer active when they should not be), and several **code-quality patterns** in `trails_screen.dart` that reduce testability.

### Architecture Maturity

Mid-way through an intentional MVVM + Repository migration. Two of five screens are fully separated. The direction is right; the investment has not yet been applied consistently. Once `TrailsScreen`, `LogScreen`, and `MapScreen` gain ViewModels and `HikeService` becomes injectable via a `HikeRepository` interface, the architecture will be genuinely consistent.

---

## Critical Issues

No true bugs remain from the v1.0.26 wave. The items below are high-impact risks.

### C1 — Wake lock held for full recording duration, not just screen-off

**File:** `lib/services/hike_recording_controller.dart:392`
**File:** `lib/services/foreground_tracking_service.dart:103`

`startRecording()` calls `ForegroundTrackingService.setWakeLock(true)` immediately and unconditionally. The wake lock spec says it should only be acquired when the screen turns off, but there is no `didChangeAppLifecycleState` callback that releases it when the app comes to the foreground (screen on). The wake lock runs the entire recording duration — including when the screen is lit and the user is looking at the map — significantly increasing battery drain on long hikes.

**Fix:** Add lifecycle handling to call `setWakeLock(false)` on `AppLifecycleState.resumed` and `setWakeLock(true)` on `paused`/`hidden`, guarded by `_isRecording`.

### C2 — Douglas-Peucker simplification runs synchronously on main isolate at save time

**File:** `lib/services/hike_recording_controller.dart:566`

`simplifyHikeRecord` is called directly inside `stopRecording()` before the final Hive write. For a 4-hour hike at ~1 Hz with a partial heading gate, the raw point count can reach 1,000–3,000 points. The iterative DP avoids stack overflow but runs O(N log N) on the main isolate, causing a visible freeze on the "Saving…" screen. `simplifyHikeRecord` has no Flutter dependencies and is already isolate-safe.

**Fix:** `await compute(simplifyHikeRecord, record)` — same pattern as `AnalyticsService.compute()`.

### C3 — `_TrailPreviewPanelState` stale bounds on widget reuse

**File:** `lib/screens/trails_screen.dart:676`

`_bounds` and `_centroid` are `late final` fields computed in `initState()`. In `didUpdateWidget`, the code detects a trail change and calls `_fitBounds()`, but `_fitBounds()` still uses the old trail's `_bounds` and `_centroid`. If Flutter reuses the state instance for a different trail (which it does when tapping between trail rows), the map fits to the wrong trail's bounds.

**Fix:** Change `late final _bounds`/`_centroid` to plain mutable fields and recompute them in `didUpdateWidget` when `importedTrailId` changes (as documented in `fix-trail-preview-bounds.md`).

---

## High Priority Improvements

### H1 — Weather timer fires when not recording

**File:** `lib/services/hike_recording_controller.dart:203`

`_weatherTimer` is started in `init()` and runs permanently — including when the user is just browsing the log and no hike is active. The background lifecycle guard prevents fetches when the app is backgrounded, but the timer fires on the foreground idle state. A hiker browsing their log runs live network weather polls the entire time.

**Fix:** Only start `_weatherTimer` inside `startRecording()` and cancel it in `stopRecording()` / `pauseRecording()`.

### H2 — Stationary mode still requests `LocationAccuracy.high`

**File:** `lib/services/location_service.dart:50`

`trackPositionStationary()` passes `accuracy: LocationAccuracy.high`. The GPS chipset power draw is dominated by the accuracy mode, not the distance/time filter. Stationary mode's intent is battery saving, but `high` accuracy keeps the chipset running at ~150 mA vs ~30–50 mA for `medium`. The accuracy gate in `_onRecordingFix` filters out poor fixes so this change has no impact on recorded data quality.

**Fix:** Change `accuracy: LocationAccuracy.high` to `accuracy: LocationAccuracy.medium` in `trackPositionStationary()`.

### H3 — Compass `StreamSubscription.pause()` buffers sensor events instead of stopping sensor

**File:** `lib/services/hike_recording_controller.dart:806`

`pauseCompass()` calls `_compassSub?.pause()`, which pauses Dart-level event delivery but does not stop the underlying magnetometer platform listener. During the pause (e.g., 60 seconds on the Log tab), the platform continues firing at 10–50 Hz and events are buffered. On `resumeCompass()`, the subscription delivers hundreds of stale events in a burst. The `_lastSetHeading` gate limits visible damage, but the sensor runs continuously and the buffer is wasteful.

**Fix:** Replace `pause()`/`resume()` with `cancel()` and re-subscribe via `_initCompass()` on resume — stops the platform listener entirely.

### H4 — `TrailsScreen` ViewModel extraction (DEFERRED spec — should be elevated)

**File:** `lib/screens/trails_screen.dart` (~858 lines)

`TrailsScreen` is the most under-refactored screen. It directly calls `ImportedTrailService.getAll()`, performs sort-and-join inline in `_buildBody`, manages multi-select state, handles import/export orchestration, and contains a 160-line inline `itemBuilder` closure (`_TrailCard` extraction per spec `fix-trail-card-extraction.md` not yet completed).

A `TrailsViewModel extends ChangeNotifier` should own: the sorted/joined `List<_DisplayTrail>`, multi-select state, panel state, and import/export delegation. The screen becomes a pure builder. This is the highest-leverage architecture improvement remaining.

### H5 — `LogViewModel` missing (same pattern as `AnalyticsViewModel`)

**File:** `lib/screens/log_screen.dart`

`LogScreen` calls `HikeService.getAll()` and sorts inline inside a `ListenableBuilder`. A thin `LogViewModel extends ChangeNotifier` that holds the sorted hike list and listens to `HikeService.version` internally would complete the MVVM pattern consistently across all five tabs. Under 50 lines of new code; high architectural payoff.

### H6 — Tile cache has no size cap (stopgap not applied)

**File:** `lib/services/tile_cache_service.dart`

There is no `clean(maxCount: N)` call after `DbCacheStore` construction. After several hikes in different areas, the SQLite tile cache can grow to hundreds of megabytes with no eviction. The spec `fix-tile-cache-stopgap.md` documents `clean(maxCount: 5000)` as the interim fix, but it is not present in the current code.

**Fix:** Add `await _store!.clean(maxCount: 5000)` immediately after `DbCacheStore` construction in `TileCacheService.init()`.

### H7 — Inject `HikeRepository` interface (spec N3)

**Files:** `lib/services/hike_service.dart`, `lib/services/hike_recording_controller.dart`, `lib/viewmodels/analytics_view_model.dart`

All services are singletons accessed via static calls or `.instance`. `HikeRecordingController` references `TrackingState.instance` on 14 lines. Neither the recording pipeline nor analytics can be unit-tested without the real GPS stack and real Hive boxes.

**Fix:** Define `abstract class HikeRepository` with `getAll()`, `save()`, `delete()`, and `version`. Pass it as a constructor parameter to `HikeRecordingController` and `AnalyticsViewModel`. `HikeService` becomes the production implementation. This is the prerequisite for meaningful integration tests.

---

## Medium Priority Improvements

### M1 — `MapScreen` polyline logic should move out of screen state

**File:** `lib/screens/map_screen.dart:56`

The incremental segment-splitting algorithm in `_onTrackingChanged` is non-trivial business logic embedded in a `State` class. Additionally, the incremental update path allocates a full copy of the last segment on every GPS fix (`List<LatLng>.from(updated.last)`) — roughly 500 `LatLng` copies per second at 1 Hz on a long trail segment.

**Fix:** Extract a `RouteSegmentsNotifier extends ChangeNotifier` that wraps `TrackingState` and exposes `List<Polyline> polylines` with mutable in-place appending for the last segment.

### M2 — `HikeRecordingController` splits into focused collaborators (spec M1)

**File:** `lib/services/hike_recording_controller.dart` (841 lines)

Six bundled concerns: compass subscription, weather polling, pedometer, drift filter, checkpoint timer, and recording lifecycle. The M1 specs (`compass-manager-extraction.md`, `weather-poller-extraction.md`) are correct and should be implemented. `CompassManager` and `WeatherPoller` as focused collaborators would reduce the controller to its core responsibility (recording lifecycle + GPS point acceptance) and eliminate `pauseCompass`/`resumeCompass` from the public API.

### M3 — `_HikeStatsSheet` widget not extracted per spec

**File:** `lib/screens/hike_detail_screen.dart:194`

The `DraggableScrollableSheet` builder is a 103-line inline widget tree. The spec `fix-hike-stats-sheet-extraction.md` documents extracting a `_HikeStatsSheet` stateless widget; it was not applied.

### M4 — `_TrailCard` not extracted per spec

**File:** `lib/screens/trails_screen.dart:476`

The `itemBuilder` is a 160-line inline closure. The spec `fix-trail-card-extraction.md` documents extracting a `_TrailCard` stateless widget; not applied.

### M5 — Guide trail `Polyline` recreated on every GPS fix

**File:** `lib/screens/map_screen.dart:155`

The guide trail `PolylineLayer` is inside the `ListenableBuilder(listenable: TrackingState.instance)` block. The guide trail geometry never changes during a session but a new `Polyline` object is allocated every GPS fix (up to 1 Hz). Cache the guide `Polyline` as a field, invalidated only when `activeGuideTrail` changes identity.

### M6 — `HikeDetailScreen` Polyline list allocated on every `build()`

**File:** `lib/screens/hike_detail_screen.dart:137`

`_segments.map((seg) => Polyline(...)).toList()` runs on every rebuild. Since `_segments` is `late final`, the `Polyline` list should also be cached as `late final` in `initState()`.

### M7 — Missing `mounted` guard in `TrailsScreen._confirmDelete`

**File:** `lib/screens/trails_screen.dart:177`

No `if (!mounted) return` after `await showDialog`. If the widget is unmounted between the dialog `await` and `_deleteImportedTrail`, a `setState` call on a dead widget throws a `FlutterError`.

### M8 — `_niceInterval` magnitude calculation is fragile

**File:** `lib/widgets/analytics_charts.dart:25`

Magnitude is computed as `raw.abs().toString().length - 1`. For values like `0.5` or `9.99`, the string length produces the wrong magnitude. Standard fix: `(log(raw) / ln10).floor()` from `dart:math`.

### M9 — `_pow10` in analytics_charts.dart reimplements `dart:math.pow`

**File:** `lib/widgets/analytics_charts.dart:33`

A manual loop replaces `pow(10, exp)`. No negative-exponent guard. Replace with `dart:math`.

### M10 — `guided hike start` business logic split across `_HomePageState` and service layer

**File:** `lib/main.dart:176`

`_HomePageState._onPendingGuideTrail` calls `TrackingState.instance.setGuideTrail(trail)` directly. This is the only direct `TrackingState` access from the UI layer. Move it into `HikeRecordingController.startGuidedRecording()` per spec `fix-guided-hike-business-logic.md`.

### M11 — Magic tab index `3` in `main.dart`

**File:** `lib/main.dart:133`

`setState(() => _currentIndex = 3)` hardcodes the Trails tab index. Add `const kTabTrails = 3` to `constants.dart`.

---

## Nice-to-Have

### N1 — Offline weather age indicator

**File:** `lib/services/hike_recording_controller.dart`

When offline, `weatherNotifier` retains the last successful value with no indication of age. A hiker mid-trail with no signal has no way to know the weather reading is 3 hours old. Add `lastWeatherFetchedAt` timestamp alongside `weatherNotifier` and display elapsed time on the weather tile when offline.

### N2 — Dependency upgrades (spec M9)

Six packages are major versions behind (tracked in `dependency-upgrade-plan.md`). The most urgent: `dio_cache_interceptor_db_store` is **discontinued** and should be migrated to `http_cache_drift_store` (tracked in `tile-cache-store-migration.md`).

### N3 — iOS ambient GPS: missing `activityType` and `pauseLocationUpdatesAutomatically`

**File:** `lib/services/location_service.dart:80`

`trackPositionAmbient()` uses the base `LocationSettings` class without an `AppleSettings` override. iOS will not automatically pause the stream during idle periods without `pauseLocationUpdatesAutomatically: true` and `activityType: ActivityType.fitness`.

### N4 — `WeatherService` is a static class (blocks mocking)

**File:** `lib/services/weather_service.dart`

All methods are `static`. Makes mocking in tests impossible. Convert to an instance class with a constructor, consistent with `UserPreferencesService`/`TilePreferenceService`.

### N5 — `constants.dart` mixes 4 conceptual groups (19 constants)

**File:** `lib/utils/constants.dart`

Brand color, fallback location, tile URLs, and GPS tuning parameters are all in one flat file. Group into `abstract final class` namespaces or split into `gps_constants.dart` / `map_constants.dart` as the file grows.

### N6 — `ImportedTrailService.fromHikeRecord` hardcodes English `'Hike Log'`

**File:** `lib/services/imported_trail_service.dart:74`

Service layer embeds a user-facing English string. Accept `sourceFilename` as a parameter at the call site where a localised string is available.

### N7 — `prefer_const_literals_to_create_immutables` lint rule not enabled

**File:** `analysis_options.yaml`

`prefer_const_constructors` and `prefer_const_declarations` are enabled but not `prefer_const_literals_to_create_immutables`. Add to prevent const-list regressions.

### N8 — `_difficultyColor` hardcodes English strings in UI

**File:** `lib/screens/trails_screen.dart:192`

Open-ended `switch` on English difficulty strings. Logic should live in the model layer or a style utility rather than the UI, and strings should come from the localisation layer.

---

## Testing

**Current coverage:** 80 pure-Dart tests across `GpxParser`, `KmlParser`, `AnalyticsService`, and `PathSimplifier`. `widget_test.dart` is a placeholder.

**Gaps:**
- No tests for `HikeRecordingController` (recording lifecycle, drift filter, checkpoint save)
- No tests for `TrackingState` (GPS fix acceptance, heading gate, stationary detection, gap markers)
- No tests for `AnalyticsViewModel` (filter state, isolate dispatch)
- No widget tests for any screen
- `WeatherService` and `LocationService` are static/singleton — untestable without refactor (N3 / H7)

**Recommendation:** The `HikeRepository` interface (H7) is the unlock. Once `HikeRecordingController` and `AnalyticsViewModel` accept injected dependencies, the most critical paths (checkpoint save, crash recovery, analytics compute) become testable with fake repositories.

---

## Suggested Refactoring Plan

Each step is independent and small enough for one session.

| Step | Spec | Impact | Effort |
|------|------|--------|--------|
| 1 | C2 — DP in isolate | Prevent save-time freeze on long hikes | XS |
| 2 | C3 — Fix stale preview bounds | Correct trail preview map | S |
| 3 | H6 — Tile cache size cap | Prevent unbounded disk growth | XS |
| 4 | H1 — Weather timer gate | Stop idle network polling | S |
| 5 | C1 — Wake lock lifecycle | Correct battery behaviour | S |
| 6 | H3 — Compass cancel/re-subscribe | Stop buffering + sensor drain | S |
| 7 | M10/M11 — Guided hike + tab constant | Clean up UI→service coupling | S |
| 8 | M7 — `mounted` guard in `_confirmDelete` | Prevent delete crash | XS |
| 9 | M6 — `Polyline` list cached in `HikeDetailScreen` | Eliminate build-time allocation | XS |
| 10 | M5 — Guide polyline cache in `MapScreen` | Reduce 1 Hz allocation | S |
| 11 | M8/M9 — `_niceInterval` + `_pow10` fix | Correct Y-axis on small values | S |
| 12 | H5 — `LogViewModel` | Complete MVVM across all tabs | M |
| 13 | M4 — `_TrailCard` extraction | Decompose 160-line itemBuilder | M |
| 14 | M3 — `_HikeStatsSheet` extraction | Decompose stats panel | S |
| 15 | M1 — `RouteSegmentsNotifier` | Testable polyline logic | M |
| 16 | M2 — `CompassManager` + `WeatherPoller` | Decompose controller | L |
| 17 | H4 — `TrailsViewModel` | Largest single refactor | L |
| 18 | H7 — `HikeRepository` interface | Unlocks unit testing | L |
| 19 | N2 — Dependency upgrades | Compatibility + security | L |
