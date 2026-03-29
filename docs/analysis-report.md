# Hike App — Full Analysis Report

**Date:** 2026-03-29
**Version analysed:** 1.0.22+23
**Analysts:** flutter-architect · flutter-code-quality · flutter-performance

---

## Summary

| Dimension | Score | Justification |
|-----------|-------|---------------|
| **Overall health** | **6.5 / 10** | A well-featured, production-shipped app with solid GPS mechanics and good incremental architecture. Let down by inconsistent patterns (MVVM only on 2 of 7 screens), a 850-line God class, zero tests for critical paths, and several performance bottlenecks that compound on long hikes. |
| **Architecture maturity** | 5 / 10 | Partial MVVM — `AnalyticsScreen`/`AnalyticsViewModel` is textbook; `TrackScreen`/`HikeRecordingController` is close; remaining 5 screens have no ViewModel and call service methods inside `build()`. |
| **Code quality** | 7 / 10 | Consistent naming, good use of ValueNotifier sub-notifiers, l10n coverage. Key gaps: dead public API, missing `mounted` check, unlocalised strings in `HikeDetailScreen`, GPX exporter duplication. |
| **Performance** | 6 / 10 | Good tile caching, granular listeners, Douglas-Peucker on save. Critical issues: `segmentsFromPoints` O(N) on every GPS fix, synchronous XML parsing blocks main thread, `HikeService.getAll()` inside `build()` on AnalyticsScreen. |
| **Testing** | 1 / 10 | 1 widget test file (default scaffold). Zero tests for GPS recording, analytics, parsers, or path simplification — the most data-critical code paths. |
| **Offline capability** | 5 / 10 | Tile caching is good but unbounded and has no pre-fetch. Weather is in-memory only (cold-start shows `--`). GPX/KML parsing freezes UI on real-world files. |

---

## Phase 1 — Codebase Inventory

```
lib/
├── l10n/               3 files  (ARB-based, en + pt)
├── models/             6 files  (HikeRecord, ImportedTrail, OsmTrail, WeatherData + generated)
├── parsers/            2 files  (GpxParser, KmlParser — pure Dart)
├── repositories/       1 file   (ImportedTrailRepository)
├── screens/            9 files  (Track, Map, Log, Trails, Analytics, HikeDetail, TrailMap, About, Splash)
├── services/          16 files  (recording, GPS, weather, compass, tiles, foreground service, …)
├── utils/              3 files  (constants, map_utils, path_simplifier)
├── viewmodels/         1 file   (AnalyticsViewModel — only screen with MVVM)
└── widgets/            4 files  (CompassPainter, AboutContent, AnalyticsCharts, MapAttribution)

Tests: 1 file (default widget_test.dart — not meaningful)
```

**Key dependencies with outdated versions:**

| Package | Current | Latest | Gap |
|---------|---------|--------|-----|
| flutter_map | 7.0.2 | 8.x | Major — new API |
| fl_chart | 0.70.2 | 1.2.x | Major |
| geolocator | 13.0.x | 14.x | Major |
| flutter_foreground_task | 8.x | 9.x | Major |
| file_picker | 8.x | 10.x | Major |
| share_plus | 10.x | 12.x | Major |
| dio_cache_interceptor_db_store | 5.x | **discontinued** | Critical |

---

## Critical Issues (fix immediately)

### C1 — `segmentsFromPoints` O(N) on every GPS fix during recording

**File:** `lib/screens/map_screen.dart`, `_onTrackingChanged`
**Impact:** After 2 hours of recording the full point list (~3 000+ points) is iterated every ~1–2 seconds. Causes compounding jank and battery drain proportional to hike duration.
**Fix:** Maintain segment cache incrementally — on each new fix, append to last segment or start a new one on NaN. O(1) per event instead of O(N).

### C2 — GPX/KML parsed synchronously on main isolate

**Files:** `lib/parsers/gpx_parser.dart`, `lib/parsers/kml_parser.dart`, call site in `TrailsImportExportService`
**Impact:** A real-world Garmin `.gpx` (500 KB, 15 000 trackpoints) blocks the UI thread for 200–500 ms on mid-range devices — ANR risk. Spec `gpx-kml-parse-isolate.md` is written but not implemented.
**Fix:** Wrap both parser calls in `compute()` at the `TrailsImportExportService` call site. Parsers are already pure-Dart with no Flutter deps.

### C3 — Zero test coverage on critical data paths

**Files:** `test/` (only `widget_test.dart`)
**Impact:** GPS recording, path simplification, analytics computation, and GPX/KML parsing have no automated regression protection. Data loss on a parse regression or streak-computation bug would go undetected.
**Fix:** Implement spec `unit-tests-pure-dart.md` (M8): `AnalyticsService`, `GpxParser`, `KmlParser`, `PathSimplifier` are all pure Dart and testable today with zero architecture changes.

### C4 — Missing `mounted` check in `_LogScaffold._delete`

**File:** `lib/screens/log_screen.dart`, line ~127
**Impact:** If the widget tree rebuilds between the `await showDialog` and `HikeService.delete`, using a stale `context` can cause a `FlutterError` or silent no-op after deletion. Spec `async-mounted-check.md` only fixed `_saveToTrails`, not `_delete`.
**Fix:** Add `if (!context.mounted) return;` after the `await` on the dialog confirmation.

---

## High Priority Improvements

### H1 — Extract `CompassManager` and `WeatherPoller` from `HikeRecordingController`

**File:** `lib/services/hike_recording_controller.dart` (850 lines)
**Problem:** The controller owns compass subscription, pedometer, weather polling timer, GPS recording lifecycle, drift filter, and checkpoint saving — six unrelated responsibilities in one class. Specs `compass-manager-extraction.md` and `weather-poller-extraction.md` are written and unimplemented.
**Fix:** Extract `CompassManager` (headingNotifier, pause/resume compass) and `WeatherPoller` (weatherNotifier, timer, 1 km trigger) as independent objects instantiated inside the controller. Reduces it to ~400 lines of cohesive recording logic.

### H2 — Add `LogViewModel` and `TrailsViewModel`

**Files:** `lib/screens/log_screen.dart`, `lib/screens/trails_screen.dart`
**Problem:** Both screens call `HikeService.getAll()` / `ImportedTrailService.getAll()` inside `build()` or widget methods. `TrailsScreen._buildBody` is 210 lines mixing sorting, model transformation, selection state, and card construction. No ViewModel exists for either screen.
**Fix:** Follow the `AnalyticsViewModel` pattern. Each ViewModel owns the sorted list, listens to version notifiers internally, and exposes async operations (delete, save, import, export) as methods returning result types.

### H3 — Cache `applyFilter` result in `AnalyticsViewModel`; remove `HikeService.getAll()` from `build()`

**Files:** `lib/screens/analytics_screen.dart` lines 38–39, `lib/viewmodels/analytics_view_model.dart`
**Problem:** `HikeService.getAll()` and `viewModel.applyFilter()` run synchronously inside `ListenableBuilder.builder` on every ViewModel notification — including every 30-second checkpoint save during recording.
**Fix:** Add an `isEmpty` / `filteredCount` property to `AnalyticsViewModel`. Remove `HikeService.getAll()` from the build method entirely.

### H4 — Fix hardcoded English strings in `HikeDetailScreen`

**File:** `lib/screens/hike_detail_screen.dart`, lines 237–296
**Problem:** All stats labels ("Date", "Start", "End", "Duration", "Distance", "GPS Points", "Steps", "Calories") are hardcoded English, not going through `AppLocalizations`. This is the only screen missed by the pt/en localisation pass.
**Fix:** Add the missing keys to `app_en.arb` and `app_pt.arb`, run `flutter gen-l10n`, and replace the literals.

### H5 — Persist last weather fetch to `SharedPreferences`

**Files:** `lib/services/weather_service.dart`, `lib/services/hike_recording_controller.dart`
**Problem:** On cold start while offline, all weather tiles show `--`. The most common hiking scenario is starting in an offline valley. Spec `offline-weather-cache.md` (N2) is written and unimplemented.
**Fix:** Write last successful `WeatherData` to `SharedPreferences` on each fetch. Read it back in `HikeRecordingController.init()` with a "last updated X min ago" label.

### H6 — Lower GPS accuracy to `LocationAccuracy.medium` in stationary mode

**File:** `lib/services/location_service.dart`
**Problem:** `trackPositionStationary()` keeps `LocationAccuracy.high`, burning full GNSS power even at rest stops. On a 6-hour hike with 30-minute summit rest this is measurable battery waste.
**Fix:** Change `LocationAccuracy.high` to `LocationAccuracy.medium` in `trackPositionStationary()`. The stationary-to-moving mode switch already handles fast lock recovery on resume.

### H7 — Pause the GPS recording stream during user Pause

**Files:** `lib/services/tracking_state.dart`, `lib/services/hike_recording_controller.dart`
**Problem:** When the user taps Pause, `_recordingPointSub` is cancelled but `TrackingState._streamSub` continues running `LocationAccuracy.high` GPS. Battery drains at full recording rate during rest breaks.
**Fix:** Add `pauseRecordingStream()` / `resumeRecordingStream()` to `TrackingState`, called by `HikeRecordingController.pauseRecording()` / `resumeRecording()`.

---

## Medium Priority Improvements

### M1 — Fix GPX exporter duplication and NaN export bug

**File:** `lib/services/gpx_exporter.dart`
`toGpxString` and `hikeRecordToGpxString` are ~30 lines of near-identical code. A bug already exists: the `HikeRecord` version exports NaN gap-marker coordinates as literal `NaN` text — invalid GPX that would fail import in any third-party app.
**Fix:** Extract `_writeGpxBody(StringBuffer, String name, List<double> lats, List<double> lons)` and skip NaN entries in both paths.

### M2 — Remove dead public API

**Files:**
- `lib/services/hike_recording_controller.dart`: `compassHeading`, `weatherData`, `hikeSteps` (superseded by notifiers)
- `lib/services/tile_preference_service.dart`: `useTopo`, `useSatellite`
- `lib/services/location_service.dart`: `getCurrentPosition()`, `requestBackgroundPermission()`

### M3 — Extract `_TrailCard` stateless widget

**File:** `lib/screens/trails_screen.dart` — spec `trail-card-extraction.md` is written. `_buildBody` is 210 lines; the card content is 160 lines inline. Extracting enables `const` construction for non-selected items.

### M4 — Extract `_HikeStatsSheet` from `HikeDetailScreen`

**File:** `lib/screens/hike_detail_screen.dart` — spec `hike-stats-sheet-extraction.md` is written. The `DraggableScrollableSheet` builder is 100 lines inline inside `build()`.

### M5 — Make `trail_map_screen._bounds` a `late final` field

**File:** `lib/screens/trail_map_screen.dart`
`_bounds` is a getter recomputing `boundsForPoints()` on every `build()`. Trail geometry is immutable; compute once in `initState()`.

### M6 — Cache `List<Polyline>` alongside `_segments` in `MapScreen`

**File:** `lib/screens/map_screen.dart`
A new `List<Polyline>` is allocated on every GPS event. Cache it alongside `_segments`.

### M7 — Remove `ValueKey` from `_TrailPreviewPanel` `FlutterMap`

**File:** `lib/screens/trails_screen.dart`
`ValueKey(widget.trail.osmId)` forces a full `FlutterMap` remount on trail change. `didUpdateWidget` already calls `_fitBounds()` — the key is redundant.

### M8 — Strengthen `analysis_options.yaml`

**File:** `analysis_options.yaml`
Add from spec `analysis-options-strengthen.md`: `cancel_subscriptions`, `close_sinks`, `always_declare_return_types`, `avoid_dynamic_calls`, `use_super_parameters`, `prefer_final_in_for_each`.

### M9 — `_ElapsedTimeTile` timer guard

**File:** `lib/screens/track_screen.dart`
`Timer.periodic` runs every second even when the Track tab is not visible. Wrap with `TickerMode` or stop when offscreen.

### M10 — Unlocalised error strings

**Files:** `lib/services/hike_recording_controller.dart` (~line 402); `lib/screens/trails_screen.dart` (lines 127/130)
Hardcoded English error strings not in `AppLocalizations`.

---

## Nice-to-Have Enhancements

### N1 — Tile pre-fetch for offline trail use
Spec `tile-prefetch-route.md`. Pre-fetch tiles at zoom 12–16 for a trail's bounding box when the user opens the trail preview. Most impactful offline-first improvement for the core use case.

### N2 — `go_router` central navigation
Replace imperative `Navigator.push` at every call site with named routes. Prerequisite for deep-link support and notification-tap navigation.

### N3 — Injectable `HikeService` and `ImportedTrailRepository`
Spec `injectable-services.md`. Convert from pure-static to singleton with injectable constructor. Prerequisite for unit testing the recording pipeline.

### N4 — Tile cache size cap (500 MB)
Spec `tile-cache-size-limit.md`. `DbCacheStore` has no size limit — silent accumulation until OS eviction causes mid-hike blank maps.

### N5 — Dependency upgrade plan
Spec `dependency-upgrade-plan.md`. `dio_cache_interceptor_db_store` is **discontinued** — blocking upgrade. `flutter_map` 7→8 and `geolocator` 13→14 are major-version upgrades with API changes.

### N6 — Contact and repo URL constants in `AboutContent`
**File:** `lib/widgets/about_content.dart`
Extract hardcoded URL and email to `const String` to avoid update-in-two-places.

---

## Phase 5 — Testing Assessment

| Test area | Current | Risk |
|-----------|---------|------|
| `AnalyticsService.compute()` | None | Silent streak/metric regression |
| `GpxParser.parse()` | None | Data loss on GPX import |
| `KmlParser.parse()` | None | Data loss on KML import |
| `PathSimplifier.simplify()` | None | NaN gap corruption on save |
| `HikeRecordingController` | None | Needs injectable services first (N3) |
| `TrackingState` | None | Needs injectable services first (N3) |
| Widget tests | 1 (default) | No UI regression protection |

All four pure-Dart modules are testable today with zero architecture changes.

---

## Suggested Refactoring Plan

### Step 1 — Critical bugs (immediate, < 1 day)
1. `mounted` check in `_delete` *(C4)*
2. Wrap parsers in `compute()` *(C2)*
3. Fix NaN GPX export + extract `_writeGpxBody` *(M1)*
4. Localise `HikeDetailScreen` stats labels *(H4)*

### Step 2 — Test suite for pure-Dart code *(C3, half day)*
`AnalyticsService`, `GpxParser`, `KmlParser`, `PathSimplifier`

### Step 3 — Performance quick wins (half day)
`late final _bounds` · remove `ValueKey` · cache `List<Polyline>` · `isEmpty` flag in AnalyticsViewModel · incremental segment computation *(C1)*

### Step 4 — Dead code + lint (half day)
Remove dead API *(M2)* · strengthen `analysis_options.yaml` *(M8)* · unlocalised strings *(M10)*

### Step 5 — Widget extraction (1 day)
`_TrailCard` *(M3)* · `_HikeStatsSheet` *(M4)* · `_ElapsedTimeTile` guard *(M9)*

### Step 6 — ViewModel extraction (2 days)
`LogViewModel` · `TrailsViewModel` *(H2)*

### Step 7 — Service refactoring (2 days)
`CompassManager` + `WeatherPoller` extraction *(H1)* · pause GPS on user pause *(H7)* · lower accuracy in stationary mode *(H6)*

### Step 8 — Offline improvements (1.5 days)
Weather `SharedPreferences` cache *(H5)* · tile cache size cap *(N4)* · tile pre-fetch *(N1)*

### Step 9 — Injectable services + deeper tests (2 days)
`HikeService` + `ImportedTrailRepository` injectable *(N3)* · recording pipeline unit tests

### Step 10 — Navigation *(N2, 1 day)*
`go_router` · named routes · replace all `Navigator.push` call sites
