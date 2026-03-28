# Hike App — Analysis Report

**Date:** 2026-03-28
**Version analysed:** 1.0.6+7
**Analysts:** flutter-architect · flutter-code-quality · flutter-performance

---

## Summary

**Overall health score: 6.5 / 10**

The app has a well-engineered GPS-critical path (recording, checkpoint saves, crash recovery, offline tile caching) and clean models/parsers. Technical debt is concentrated in three areas: `TrailsScreen` (a god-class with no ViewModel), the lack of any dependency injection (services are untestable statics), and several battery/crash risks in the recording pipeline. Zero test coverage is the single most dangerous long-term risk.

**Architecture maturity:** MVVM applied correctly to Track/Map; no pattern applied to Log/Trails/Detail screens. Inconsistent service layer (some static, some singletons, one proper repository).

---

## Critical Issues

### CRIT-1 — `bestForNavigation` GPS mode drains battery on long hikes
**File:** `lib/services/location_service.dart:30`
`LocationAccuracy.bestForNavigation` keeps the GPS radio at maximum power. On a 6-hour alpine hike this is a significant drain. The 30 m accuracy gate (`kMaxAcceptableAccuracyMetres`) already ensures point quality — `bestForNavigation` adds no benefit once the chipset has lock.
**Fix:** Change to `LocationAccuracy.high`.

### CRIT-2 — `WeatherService` silently swallows all exceptions
**File:** `lib/services/weather_service.dart:21-28, 51-56`
Both `catch` blocks catch every exception and return `null` with no logging. A broken API contract, `SocketException`, or JSON schema change are all invisible to the caller and to developers.
**Fix:** Add `debugPrint` in each catch block; separate network failures from parse failures.

### CRIT-3 — `_bounds` / `_centroid` are O(N) getters called on every `build`
**File:** `lib/screens/trails_screen.dart:776-784`
Both are getter methods that call `boundsForPoints()` on every access. `_centroid` calls `_bounds` internally — two full geometry scans per frame. The spec `trail-preview-bounds-cache.md` is marked *implemented* in CLAUDE.md but the code still uses getters.
**Fix:** Promote to `late final` fields assigned in `initState`.

### CRIT-4 — GPX/KML parsing runs synchronously on the main isolate
**Files:** `lib/screens/trails_screen.dart:152-165`, `lib/parsers/gpx_parser.dart`, `lib/parsers/kml_parser.dart`
`utf8.decode` + `XmlDocument.parse` + `computeDistanceKm` all run synchronously on the main isolate. A 10-hour Garmin track (~36 000 trkpt elements, 5–15 MB) will freeze the UI for 1–5 seconds and risks ANR on low-end devices. Both parsers have no Flutter/Hive dependencies — they are `compute()`-safe.
**Fix:** Wrap parse+distance call in `compute()`.

### CRIT-5 — `computeDistanceKm` calls `Geolocator.distanceBetween` per point via platform channel
**File:** `lib/utils/map_utils.dart:33-44`
`Geolocator.distanceBetween` is a synchronous platform-channel call. For 30 000 point pairs this is 29 999 round-trips (~3 s of main-isolate blocking). It also **cannot be used inside `compute()`** — platform channels are not accessible from spawned isolates, causing `MissingPluginException`.
**Fix:** Implement a pure-Dart Haversine formula in `map_utils.dart` for parser/exporter use.

### CRIT-6 — ID collision risk in `ImportedTrailRepository.toOsmTrail`
**File:** `lib/repositories/imported_trail_repository.dart:52`
`osmId: -trail.id.hashCode.abs()` — UUID v4 strings hash to a 32-bit space, making collisions possible. Trail selection in `TrailsScreen` uses `osmId` equality; a collision makes two trails indistinguishable in the preview panel.
**Fix:** Use the UUID string directly for selection, not its hash.

---

## High Priority

### H-1 — Wake lock acquired unconditionally; not gated on screen state
**File:** `lib/services/hike_recording_controller.dart:332-333, 506-507`
The wake lock is held for the entire recording duration regardless of whether the screen is on. During a 6-hour hike with the screen mostly on, this prevents the CPU from sleeping between GPS events.
**Fix:** Gate `setWakeLock` on `AppLifecycleListener` (screen off → on) rather than recording start/stop.

### H-2 — Unbounded GPS coordinate lists + synchronous Hive serialisation on main isolate
**Files:** `lib/models/hike_record.dart:27-28`, `lib/services/hike_recording_controller.dart:388-427`
`latitudes`/`longitudes` grow without bound. Every checkpoint serialises the entire `HikeRecord` to Hive on the main isolate. At 10 000+ points this can take 50–200 ms on low-end devices, risking dropped frames.
**Fix (short-term):** Use `compute()` for `HikeService.save()` when point count exceeds ~1 000.
**Fix (long-term):** Implement Douglas-Peucker simplification (already spec'd, deferred).

### H-3 — `_TrailsScreenState` is a god-class (~450 lines of non-UI logic)
**File:** `lib/screens/trails_screen.dart:121-444`
File I/O, permission checks, ZIP bundling, OS version detection, dialog presentation, and trail conversion all live in one `State` class alongside all rendering code. The DEFERRED spec `trails-viewmodel-extraction.md` covers the fix.
**Fix:** Extract `TrailImportExportController extends ChangeNotifier`.

### H-4 — `onError` callback couples `HikeRecordingController` to UI
**File:** `lib/services/hike_recording_controller.dart:321, 434`
The controller accepts `required void Function(String) onError` in `startRecording` and `stopRecording`, giving it knowledge of UI affordances. `_lastError` already exists as a field.
**Fix:** Remove the callback; set `_lastError` + `notifyListeners()`; let `TrackScreen` read it via `ListenableBuilder`.

### H-5 — `_TrailPreviewPanelState._fitBounds` uses a 350 ms timing hack
**File:** `lib/screens/trails_screen.dart:791-799`
`Future.delayed(350ms, _fitBounds)` waits slightly longer than the 300 ms `AnimatedContainer`. If the animation duration ever changes the delay must be manually updated.
**Fix:** Use `addPostFrameCallback` or an `AnimationController` completion callback.

### H-6 — `TapGestureRecognizer` in `AboutContent` is never disposed — memory leak
**File:** `lib/widgets/about_content.dart:70-72, 92-94`
`TapGestureRecognizer` extends `GestureRecognizer`, which must be disposed. `AboutContent` is a `StatelessWidget` with no `dispose`.
**Fix:** Convert `AboutContent` to a `StatefulWidget` and dispose the recognizers in `dispose()`, or replace `RichText`+recognizer with `GestureDetector`/`InkWell`.

### H-7 — `_recordingPointController` closed permanently; singleton survives activity re-creation
**File:** `lib/services/tracking_state.dart:200-204`
`cancelStream()` closes `_recordingPointController`. On Android activity re-creation, `dispose()` calls `cancelStream()`, permanently closing the stream. The new `HikeRecordingController` subscribes to a closed stream — the `isClosed` guard silently drops all recording points with no error.
**Fix:** Lazily re-create the `StreamController` in `_startRecordingStream` if closed.

### H-8 — `_HomePageState._onPendingGuideTrail` async errors not caught
**File:** `lib/main.dart:143-158`
This `Future<void>` is stored as a `VoidCallback` listener. Exceptions in async gaps propagate as unhandled Zone errors, bypassing `onError`.
**Fix:** Wrap the body in `try/catch` that calls `_showError`.

### H-9 — Tile layer + topo FAB duplicated verbatim across four screens
**Files:** `map_screen.dart`, `hike_detail_screen.dart`, `trail_map_screen.dart`, `trails_screen.dart`
The `ListenableBuilder` + `TileLayer` pattern and the topo-toggle `FloatingActionButton` are copied four times.
**Fix:** Extract `_TopoTileLayer` and `_TopoToggleFab` shared widgets.

### H-10 — Discontinued `dio_cache_interceptor_db_store` in production
**File:** `pubspec.yaml:59`
No future security or API-compatibility fixes will be released for this package.
**Action:** Monitor pub.dev; migrate when `dio_cache_interceptor_drift_store` is published (spec: `tile-cache-store-migration.md`).

---

## Medium Priority

### M-1 — Ambient GPS stream has no time-interval guard at vehicle speeds
**File:** `lib/services/location_service.dart:41-48`
At 100 km/h, `distanceFilter: 50` fires ~2 000 times/hour. Add `timeInterval: 30000`.

### M-2 — Magnetometer runs at native frequency (~20 Hz); only UI rebuilds are throttled
**File:** `lib/services/hike_recording_controller.dart:196-214`
~430 000 closure invocations on a 6-hour hike. The 1-degree gate suppresses notifiers but not the closure.
**Fix:** Add a 200 ms `throttle` before the 1-degree gate.

### M-3 — `_buildBody` allocates `OsmTrail` + `List<LatLng>` for every trail on every rebuild
**File:** `lib/screens/trails_screen.dart:572-575`
50 trails × 500 points = 25 000 `LatLng` allocations per rebuild.
**Fix:** Cache `OsmTrail` objects in the service or outside the `ListenableBuilder`.

### M-4 — `PolylineLayer` repaints entire recorded track on every GPS fix
**File:** `lib/screens/map_screen.dart:105-114`
Full polyline repaint every 3–4 seconds during recording. Worsens with track length.
**Fix (short-term):** Add `RepaintBoundary` around `PolylineLayer`. **Fix (long-term):** Douglas-Peucker.

### M-5 — No DI; services are untestable static singletons
All services accessed via static methods or `.instance`. Cannot unit-test `HikeRecordingController` without starting a real GPS stream and foreground service.
**Fix:** Constructor-inject dependencies; use interfaces at service boundaries.

### M-6 — `HikeRecord` stores lat/lon as parallel arrays
**File:** `lib/models/hike_record.dart:27-28`
Two lists that must always be the same length. A future edit touching only one silently corrupts data.
**Fix:** Introduce `@HiveType GpsPoint` with `@HiveField(9) List<GpsPoint> points`.

### M-7 — Startup orchestration logic in `SplashScreen._initAndNavigate`
**File:** `lib/screens/splash_screen.dart:37-77`
Service init order, crash-recovery decision, and navigation live in a widget method.
**Fix:** Extract `AppInitializer` returning an `AppStartResult` sealed class.

### M-8 — `IntentHandlerService` static mutable callbacks are fragile
**File:** `lib/main.dart:123-125`
Static nullable callbacks can silently become stale after widget disposal.
**Fix:** Use `StreamController.broadcast()`; subscribe/cancel in `initState`/`dispose`.

### M-9 — `_TrackScreen._buildTile` and `_ElapsedTimeTile.build` duplicate tile structure
**File:** `lib/screens/track_screen.dart:350-380, 428-457`

### M-10 — `WeatherService` creates a new TCP connection per fetch
**File:** `lib/services/weather_service.dart:21-22`
**Fix:** Share an `http.Client` instance.

### M-11 — `CLAUDE.md` version mismatch (`1.0.6+7` in pubspec vs `1.30.0+37` in docs)

### M-12 — `LogScreen._delete` dialog uses outer `context` instead of dialog context
**File:** `lib/screens/log_screen.dart:63-64`

---

## Low Priority

### L-1 — `LocationService.getCurrentPosition` is dead code
**File:** `lib/services/location_service.dart:19-24`

### L-2 — `HikeService.getAll()` double-allocates a reversed list
**File:** `lib/services/hike_service.dart:19-21`

### L-3 — `_LocationMarker.heading` defaults to `0.0` before first GPS fix
**File:** `lib/screens/map_screen.dart:198-201`
Use `double?` with null guard, matching `CompassPainter.heading`.

### L-4 — `OsmTrail` doc comment still references deleted Overpass API
**File:** `lib/models/osm_trail.dart:3`

### L-5 — `HikeRecord.name` calls `DateTime.now()` four times
**File:** `lib/services/hike_recording_controller.dart:336-339`
Capture once; use `DateFormat` from `intl`.

### L-6 — EMA altitude resets to 0.0 at recording start, discarding ambient baseline
**File:** `lib/services/tracking_state.dart:151`

### L-7 — Three separate `ValueListenableBuilder`s for weather tiles that always update together
**File:** `lib/screens/track_screen.dart:190-215`

### L-8 — `analysis_options.yaml` missing useful rules
Add: `cancel_subscriptions`, `close_sinks`, `prefer_final_fields`, `always_put_required_named_parameters_first`, `prefer_const_literals_to_create_immutables`.

### L-9 — Test coverage is zero
**File:** `test/widget_test.dart`
Pure-Dart logic trivially testable without Flutter or Hive: `GpxParser`, `KmlParser`, `CompassService.headingToCardinal`, `boundsForPoints`, `HikeRecord.durationFormatted`, `WeatherData` WMO mapping.

---

## Suggested Refactoring Plan

Ordered by impact-to-effort ratio. Each step is scoped to one session.

### Step 1 — Battery quick wins (½ day)
- `bestForNavigation` → `high` (`location_service.dart:30`)
- Add `timeInterval: 30000` to ambient stream (`location_service.dart:41-48`)
- Add 200 ms throttle to compass stream (`hike_recording_controller.dart:196-214`)
- Share `http.Client` in `WeatherService`

### Step 2 — Fix crash risks in import pipeline (1 day)
- Implement pure-Dart Haversine in `map_utils.dart` (replaces platform-channel calls in parsers)
- Wrap GPX/KML parse in `compute()` (`trails_screen.dart:152-165`)
- Promote `_bounds`/`_centroid` to `late final` in `_TrailPreviewPanelState`
- Fix `_recordingPointController` re-creation on activity restart (`tracking_state.dart:200-204`)

### Step 3 — Fix memory leak + resource disposal (½ day)
- Convert `AboutContent` to `StatefulWidget`; dispose `TapGestureRecognizer`s
- Fix `osmId` hash collision: use UUID string for trail selection equality
- Add `debugPrint` to `WeatherService` catch blocks

### Step 4 — `TrailsScreen` ViewModel extraction (1–2 days)
- Implement `docs/features/trails-viewmodel-extraction.md`
- Extracts I/O, permissions, ZIP logic into `TrailImportExportController`
- Cache `OsmTrail` objects (fixes M-3)
- Move ZIP compression to `compute()` (fixes medium CR-5)
- Replace 350 ms timing hack with proper callback (fixes H-5)
- Extract `_TrailCard` widget (fixes H-3 partly)

### Step 5 — Wake lock + async error handling (½ day)
- Implement `AppLifecycleListener` in `_HomePageState` to gate wake lock on screen state
- Add `try/catch` to `_onPendingGuideTrail`
- Replace `IntentHandlerService` static callbacks with broadcast streams

### Step 6 — Recording pipeline hardening (1 day)
- Remove `onError` callback from `HikeRecordingController`; expose `lastError` `ValueNotifier`
- Move `HikeService.save()` into `compute()` when point count > 1 000
- Fix `_stepSub.cancel()` to be awaited in `stopRecording`
- Fix `HikeRecord` parallel arrays → `GpsPoint` Hive type (requires `build_runner`)

### Step 7 — Douglas-Peucker path simplification (½ day)
- Implement `docs/features/path-simplification.md`
- Permanently resolves H-2, M-4, and unbounded memory growth

### Step 8 — Shared widgets + code deduplication (½ day)
- Extract `_TopoTileLayer` and `_TopoToggleFab`
- Merge `_buildTile` / `_ElapsedTimeTile`
- Consolidate `HikeService` / `ImportedTrailRepository` naming

### Step 9 — Unit tests (ongoing)
- `GpxParser` / `KmlParser` round-trip tests
- `CompassService.headingToCardinal` exhaustive test
- `boundsForPoints` edge cases (empty list, single point)
- `WeatherData` WMO code mapping regression tests
- Enable `cancel_subscriptions` and `close_sinks` lint rules

### Step 10 — Documentation sync (½ day)
- Reconcile `CLAUDE.md` version with `pubspec.yaml`
- Fix stale `LogScreenState` public comment in CLAUDE.md
- Update `OsmTrail` doc comment
- Add milestone to `tile-cache-store-migration.md` DEFERRED label

---

*Report generated by static analysis + manual review of all 37 Dart source files.*
