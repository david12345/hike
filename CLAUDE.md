# CLAUDE.md — Hike App

## Project Overview

| Field | Value |
|-------|-------|
| Name | Hike |
| Description | Essential features for hiking |
| Path | `/home/dealmeida/hike` |
| Package | `com.dealmeida.hike` |
| Version | 1.0.16+17 |
| Type | Flutter Android app |
| GitHub | https://github.com/david12345/hike |

---

## Features

| Tab | Screen | Description |
|-----|--------|-------------|
| Track | `track_screen.dart` | GPS recording with timer, distance, points, live compass (with degree at center), lat/lon/altitude, weather, air pressure. Full-screen layout. |
| Map | `map_screen.dart` | Live location + route polyline on OpenStreetMap (flutter_map). |
| Log | `log_screen.dart` | List of all saved hikes. Tap to view route on map in detail screen (OSM ↔ OpenTopoMap tile toggle). |
| Trails | `trails_screen.dart` | Real hiking trails from Overpass API (10 km radius). Tap to view on map. |
| Stats | `analytics_screen.dart` | Date-range filter, summary metrics, personal bests, streaks, Distance by Month / Day of Week / Distribution charts. About accessible from AppBar overflow. |

---

## Architecture

```
lib/
├── main.dart                       # App entry, SplashScreen home, MaterialApp, bottom NavigationBar (5 tabs); cachedAppVersion global
├── models/
│   ├── hike_record.dart            # Hive model: id, name, times, distance, GPS points
│   ├── hike_record.g.dart          # Hive adapter (generated — do not edit manually)
│   ├── osm_trail.dart              # OsmTrail model with LatLng geometry
│   └── weather_data.dart           # WeatherData model with WMO code mapping
├── parsers/
│   ├── gpx_parser.dart             # GPX 1.1 XML → List<ImportedTrail> (no Flutter/Hive deps)
│   └── kml_parser.dart             # KML XML → List<ImportedTrail> (no Flutter/Hive deps)
├── repositories/
│   └── imported_trail_repository.dart # Hive CRUD for ImportedTrail
├── screens/
│   ├── splash_screen.dart          # Splash: inits Hive, TrackingState, TileCacheService; crash recovery dialog
│   ├── track_screen.dart           # Display-only; reads HikeRecordingController via ListenableBuilder
│   ├── map_screen.dart             # flutter_map live map; reads TrackingState for position
│   ├── log_screen.dart             # Past hikes list; rebuilds via HikeService.version ValueNotifier
│   ├── hike_detail_screen.dart     # Route map + DraggableScrollableSheet stats panel; OSM ↔ OpenTopoMap toggle
│   ├── trails_screen.dart          # Imported trail browser; rebuilds via ImportedTrailService.version
│   ├── trail_map_screen.dart       # Full-screen map for a single OsmTrail (deepOrange polyline)
│   ├── analytics_screen.dart       # Stats tab: date filter, summary metrics, personal bests, streaks, 3 fl_chart charts.
│   └── about_screen.dart           # App info (black bg, centered). Accessible via Analytics AppBar overflow menu.
├── services/
│   ├── hike_service.dart           # Hive CRUD for HikeRecord + version ValueNotifier + findUnfinished()
│   ├── hike_recording_controller.dart # ChangeNotifier: GPS recording lifecycle, checkpoint saves, error handling
│   ├── location_service.dart       # Geolocator wrapper; trackPosition() (high) + trackPositionAmbient() (medium)
│   ├── tracking_state.dart         # Singleton ChangeNotifier: sole GPS stream owner, ambient/recording modes
│   ├── weather_service.dart        # Open-Meteo API client — temperature, weather code, air pressure
│   ├── compass_service.dart        # flutter_compass wrapper with headingToCardinal()
│   ├── tile_preference_service.dart # ChangeNotifier singleton: OSM ↔ OpenTopoMap preference + SharedPreferences
│   ├── tile_cache_service.dart     # Shared flutter_map_cache DbCacheStore (30-day disk cache)
│   ├── imported_trail_service.dart # Thin facade over parsers/exporter/repository; version ValueNotifier
│   ├── gpx_exporter.dart           # GPX serialisation + file I/O + ZIP bundling
│   ├── foreground_tracking_service.dart # Android foreground service for background GPS; wake lock enabled
│   ├── intent_handler_service.dart # Android file-open intent handler (GPX/KML/XML)
│   └── analytics_service.dart      # Pure-Dart: AnalyticsService.compute(), AnalyticsStats, MonthlyBucket, streak helpers
├── utils/
│   ├── map_utils.dart              # boundsForPoints(List<LatLng>) → LatLngBounds
│   └── constants.dart              # kFallbackLocation, kOsmTileUrl, kTopoTileUrl, kForegroundServiceId
└── widgets/
    ├── compass_painter.dart        # Shared CompassPainter (CustomPainter) — draws rose + degree at center
    ├── about_content.dart          # Shared content widget for SplashScreen + AboutScreen (centred layout)
    └── map_attribution_widget.dart # OSM/OpenTopoMap attribution overlay for map screens
```

---

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_map | ^7.0.2 | OpenStreetMap tiles — no API key required |
| latlong2 | ^0.9.1 | LatLng coordinates for flutter_map |
| geolocator | ^13.0.1 | GPS location stream (distanceFilter: 5m recording / 50m ambient) |
| hive | ^2.2.3 | Local NoSQL storage for hike records |
| hive_flutter | ^1.1.0 | Hive Flutter init helper |
| hive_generator | ^2.0.1 | Generates `hike_record.g.dart` adapter |
| build_runner | ^2.4.13 | Code generation runner |
| intl | ^0.20.2 | Date formatting |
| uuid | ^4.5.1 | Generates unique hike IDs |
| http | ^1.3.0 | HTTP client for Open-Meteo API |
| flutter_compass | ^0.8.1 | Device compass heading stream |
| package_info_plus | ^8.3.0 | Runtime version from pubspec.yaml |
| collection | ^1.19.1 | firstWhereOrNull and other Iterable extensions |
| flutter_map_cache | ^1.5.0 | Disk tile caching via CachedTileProvider |
| dio_cache_interceptor | ^3.5.0 | HTTP cache interceptor (peer dep of flutter_map_cache) |
| dio_cache_interceptor_db_driver | ^2.2.0 | SQLite cache store (peer dep of flutter_map_cache) |
| fl_chart | ^0.70.0 | Charts for Analytics screen (bar charts) |
| flutter_launcher_icons | ^0.14.3 | (dev) Generates Android launcher icons |
| flutter_localizations | sdk: flutter | Localizations delegates for forced English locale |

---

## Important Implementation Notes

### Splash screen / Hive init
`HikeService.init()` is called from `SplashScreen.initState()` (NOT from `main()`). The splash uses `Future.wait([HikeService.init(), Future.delayed(2s)])` so Hive is ready before navigating to `HomePage`. Content is centered via `Center()` with no `SafeArea` (avoids asymmetric inset off-centering).

### AboutContent shared widget
`lib/widgets/about_content.dart` is used by both `SplashScreen` and `AboutScreen`. Accepts `showAnimation: bool` (default `true`):
- `false` → `Center(child: _buildInfoBlock())` — no SafeArea, true screen center (used by SplashScreen)
- `true` → `SafeArea + Column + Spacer + HikerAnimation` — animation anchored at bottom (used by AboutScreen)

### Compass
`CompassService.headingStream` — wraps `FlutterCompass.events`. Throttled in UI to rebuild only when heading changes ≥1°. `CompassPainter` draws the rose AND the degree value (e.g. "247°") at the geometric center — text is drawn after `canvas.restore()` so it stays upright while the rose rotates. heading parameter is nullable (`double?`); shows `"--°"` when unavailable.

### Track screen weather
`WeatherService.fetchCurrent(lat, lon)` called on first GPS fix, then every 5 minutes or after 1 km movement. Shows weather description + air pressure (hPa). No API key needed (Open-Meteo).

### Hive adapter regeneration
When changing `HikeRecord` fields, regenerate the adapter:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### App icon regeneration
If `docs/features/app_icon.png` changes, regenerate Android launcher icons:
```bash
dart run flutter_launcher_icons
```

### Release APK path
The Gradle `applicationVariants.all` block renames the Android build output to `hike.apk`. Use this path for releases:
```
build/app/outputs/apk/release/hike.apk
```
Note: Flutter also copies a fixed-name `app-release.apk` to `build/app/outputs/flutter-apk/` — ignore that one.

### LogScreenState is public
`LogScreenState` (not `_LogScreenState`) is intentionally public so `main.dart` can hold a `GlobalKey<LogScreenState>` and call `refresh()` when a hike is saved from the Track tab.

### Map tile provider
Two tile layers supported, toggled via `TilePreferenceService` (persisted with SharedPreferences):
- **OSM** (default): `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- **OpenTopoMap**: `https://tile.opentopomap.org/{z}/{x}/{y}.png`

`userAgentPackageName` is set to `com.dealmeida.hike` as required by OSM policy. The toggle FAB appears on `MapScreen`, `TrailMapScreen`, and `HikeDetailScreen`. On `HikeDetailScreen` it is positioned top-right (`top: 16, right: 16`) to avoid overlap with the `DraggableScrollableSheet` at the bottom.

### Force English locale
App locale is pinned to English regardless of device language:
- `lib/main.dart`: `locale: const Locale('en')`, `supportedLocales`, `localizationsDelegates`, `Intl.defaultLocale = 'en'`
- `android/app/build.gradle.kts`: `resConfigs("en")` strips non-English resources from APK
- `MainActivity.kt`: `attachBaseContext` override forces `Locale.ENGLISH` on the Activity context — this makes the SAF file/folder picker render in English

### GPS distanceFilter
Location stream uses `distanceFilter: 5` (meters) to avoid jitter and excessive battery use. Adjust in `location_service.dart` if more precision is needed.

### Overpass API (deleted)
`OverpassService` was deleted in v1.25.0 (UI removed in v1.18.0, file never cleaned up). Recoverable from git history: `git log --all -- lib/services/overpass_service.dart`.

### Android permissions
`AndroidManifest.xml` includes:
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `INTERNET` (for map tiles, Overpass API, Open-Meteo API)

---

## Assets

| Path | Purpose |
|------|---------|
| `assets/images/app_icon.png` | App icon used in splash/about screens |
| `docs/features/app_icon.png` | Source icon for `flutter_launcher_icons` generation |

---

## Android SDK

> Inherited from the parent environment — see `/home/dealmeida/CLAUDE.md`.

**Always ensure `android/local.properties` contains:**
```properties
sdk.dir=/home/dealmeida/android-sdk
flutter.sdk=/home/dealmeida/flutter
```
This file is git-ignored and must be recreated after a fresh clone.

---

## Build & Release Workflow

```bash
# 1. Make changes
# 2. If HikeRecord model changed:
dart run build_runner build --delete-conflicting-outputs

# 3. If app icon changed:
dart run flutter_launcher_icons

# 4. Verify
flutter analyze

# 5. Bump version in pubspec.yaml (REQUIRED before building)
#    Update both semver and build number: version: X.Y.Z+N

# 6. Commit and push
git add <files>
git commit -m "message"
git push

# 7. Build release APK
flutter build apk --release

# 8. Create GitHub release with APK
gh release create vX.Y.Z build/app/outputs/apk/release/hike.apk
```

> Every push must be followed by a GitHub Release with the APK attached.
> Always bump `pubspec.yaml` version before building — forgetting causes the installed app to display the old version number.

### After every release — update CLAUDE.md

After each release, both `CLAUDE.md` files must be kept in sync with the current state of the project:

- **`/home/dealmeida/hike/CLAUDE.md`** — update:
  - Project Overview `Version` field
  - Features table (if tabs/screens changed)
  - Architecture tree (if files were added/removed/renamed)
  - Key Dependencies (if packages were added/removed)
  - Important Implementation Notes (if new patterns or gotchas emerged)
  - Release History table (add the new version row)
  - Feature Specs table (add any new spec files)

- **`/home/dealmeida/CLAUDE.md`** — update:
  - Hike project `Version` field

This keeps CLAUDE.md as the single source of truth for future conversations.

---

## Release History

| Version | Description |
|---------|-------------|
| v1.0.0 | Initial release: GPS tracking, map, log, trail browser |
| v1.1.0 | Trails from Overpass API (real OSM hiking routes) |
| v1.2.0 | Dashboard screen (GPS, compass, altitude, weather, pressure) |
| v1.3.0 | Splash screen, track screen enhancements (compass + GPS info), custom app icon |
| v1.4.0 | Track screen weather/pressure, About tab, splash black bg, dashboard removed |
| v1.5.0 | Track screen full-screen layout, app description updated |
| v1.6.0 | Compass degree at center, release APK renamed to hike.apk |
| v1.7.0 | Hiker climbing mountain animation on About screen |
| v1.8.0 | Splash screen content truly centered (no SafeArea offset) |
| v1.9.0 | Background GPS tracking via Android foreground service |
| v1.10.0 | GPX/KML trail import and local storage on Trails screen |
| v1.11.0 | Temperature, step counter, calories, speed tiles; Track screen redesign |
| v1.12.0 | Hike detail map expanded to full screen with interactive controls |
| v1.13.0 | Persistent draggable stats panel on hike detail map |
| v1.14.0 | Network/scope filter on Trails screen |
| v1.15.0 | My Trails screen with GPX import |
| v1.16.0 | Remove Trails screen filters; fix FilePicker error |
| v1.17.0 | GPX import/delete moved to Trails; live track + topo map |
| v1.17.1 | Filter file picker to .gpx files only |
| v1.18.0 | Trails: split-screen map, tile toggle, save to trails, GPX export; remove Overpass API and About animation |
| v1.18.1 | Fix FilePicker crash on GPX import (use FileType.any) |
| v1.18.2 | Update app icon to app_icon1.png |
| v1.18.3 | Fix trail preview panel map not fitting trail bounds |
| v1.18.4 | Revert to app_icon.png; icon centred on splash/about screens |
| v1.18.5 | Add direction arrow on map marker while recording |
| v1.19.0 | Map: start-point marker + direction arrow; Log: steps & calories |
| v1.20.0 | Trails: delete button, KML import, export fixes, local save; About subtitle |
| v1.20.1 | Fix: skip storage permission check on Android 10+ for Save to device |
| v1.21.0 | Trails: multi-select export, multi-file import, .xml KML support |
| v1.21.1 | Trails: auto-refresh list after saving a trail from Log screen |
| v1.22.0 | Add Android file-open intent: open GPX/KML/XML files directly in Hike |
| v1.22.1 | Trails: folder picker for Save to device |
| v1.24.0 | Hike Detail: OSM ↔ OpenTopoMap tile toggle; force English locale app-wide |
| v1.26.0 | Battery/performance/reliability/offline: single GPS stream, HikeRecordingController, checkpoint saves with crash recovery, offline tile caching, TilePreferenceService ChangeNotifier, GlobalKey → ValueNotifier, ImportedTrailService split, build-method caching, DraggableScrollableSheet stats panel, dead code removal |
| v1.27.0 | Code quality/performance pass: compass pause on tab switch, wake lock lifecycle, granular TrackScreen listeners, MapScreen scoped GPS rebuild, altitude EMA smoothing, batch crash-recovery replay, recording stream (MP-5), pedometer cache, tile provider cache, parser deduplication, WeatherData pure Dart, package-name/URL constants, Hive box ownership fix, intent handler error reporting, about animation restored, lint rules improved, AppInfoService |
| v1.28.0 | Guided hike start from Trails screen: walk icon button per trail row starts recording and shows trail as green polyline on Map screen; clears on stop |
| v1.29.0 | Remove hiker animation entirely (delete hiker_animation.dart); unify AboutContent layout; splash screen shows version centred like About tab |
| v1.30.0 | True-center layout on Splash and About: replace SafeArea+Spacers with Center widget in AboutContent |
| v1.31.0 | GPS recording density: distanceFilter 3 m → 1 m, timeInterval 5 s → 2 s, heading-change trigger (10°) with speed guard (0.3 m/s) to faithfully capture roundabouts and switchbacks |
| v1.32.0 | Fix version blank on splash: await endOfFrame after setState so version is painted before Navigator.pushReplacement fires |
| v1.33.0 | Android Auto screen: compass, lat/lon/alt, live OSM tile map via native CarAppService + MethodChannel bridge |
| v1.34.0 | Satellite map view: three-way tile cycle OSM → Topo → Satellite using Esri World Imagery; TileMode enum replaces bool; FAB icon previews next state |
| v1.35.0 | Douglas-Peucker path simplification at save time: pure-Dart, NaN-gap-aware, epsilon = 3 m; ~90% point reduction on long hikes |
| v1.36.0 | Android Auto visibility fix: move setSurfaceCallback to onGetTemplate(), AutoDataPlugin FlutterPlugin, document Unknown sources setup |
| v1.0.16 | Analytics screen: hikes per month, distance over time, distance distribution, personal bests, streaks, date range filter |
| v1.0.15 | Sort order toggle for Log (by date) and Trails (by name) screens; preference persisted via SharedPreferences |

---

## Agent Instructions

### flutter-architect
Always generate the spec file and save it to `docs/features/`. Every spec file **must include a User Story** section (e.g. "As a hiker, I want to … so that …") before the requirements.

---

## Feature Specs

All feature specs are in `docs/features/`:

| File | Feature |
|------|---------|
| `trails-overpass-api.md` | Overpass API trail browser |
| `dashboard-screen.md` | Environmental dashboard screen (removed in v1.4.0) |
| `track-screen-enhancements.md` | Compass + GPS info on Track screen |
| `track-screen-weather.md` | Weather + pressure on Track screen |
| `track-screen-fullscreen-layout.md` | Full-screen Track layout |
| `splash-screen.md` | Branded splash screen |
| `splash-screen-black.md` | Black background splash |
| `splash-screen-centered.md` | True centering fix |
| `app-icon.md` | Custom launcher icon |
| `app-name-description.md` | App name and description update |
| `delete-dashboard.md` | Dashboard screen removal |
| `about-tab.md` | About tab with shared content widget |
| `about-hiker-animation.md` | Hiker climbing mountain animation |
| `apk-rename.md` | Rename release APK to hike.apk |
| `compass-center-degree.md` | Compass degree drawn at center of rose |
| `map-tile-toggle.md` | OSM ↔ OpenTopoMap tile toggle on Hike Detail screen |
| `force-english-locale.md` | Force English locale app-wide including file/folder pickers |
| `hike-detail-visible-panel.md` | Persistent DraggableScrollableSheet stats panel on hike detail |
| `remove-dead-code.md` | Delete trail.dart, overpass_service.dart, _StatChip, saveAllToDownloads |
| `shared-map-utilities.md` | boundsForPoints utility, constants.dart, collection package |
| `tile-preference-observable.md` | TilePreferenceService as ChangeNotifier singleton |
| `replace-global-key-communication.md` | Replace GlobalKeys with ValueNotifier version counters |
| `split-imported-trail-service.md` | GpxParser, KmlParser, GpxExporter, ImportedTrailRepository |
| `build-method-performance.md` | late final caches, _ElapsedTimeTile extraction, points cache |
| `single-gps-stream.md` | Single GPS stream, tiered accuracy, HikerAnimation TickerMode |
| `hike-recording-controller.md` | HikeRecordingController ChangeNotifier extracted from TrackScreen |
| `gps-checkpoint-saves.md` | Checkpoint saves every 10pts/30s; crash recovery dialog |
| `map-tile-caching.md` | Offline tile caching via flutter_map_cache (30-day SQLite store) |
| `wake-lock-lifecycle.md` | Wake lock enabled only when screen is off during recording |
| `compass-stream-pause-resume.md` | Pause compass stream when leaving Track tab |
| `track-screen-granular-listeners.md` | Per-subsystem ValueNotifier listeners on TrackScreen |
| `map-screen-scoped-rebuild.md` | MapScreen GPS layers in scoped ListenableBuilder |
| `altitude-ema-smoothing.md` | EMA smoothing for GPS altitude readings |
| `batch-replay-points.md` | Single notifyListeners on crash-recovery point replay |
| `tracking-state-recording-stream.md` | Replace mutable onRecordingPoint callback with broadcast stream |
| `pedometer-availability-cache.md` | Cache pedometer availability to skip 500 ms probe on cold start |
| `tile-provider-cache.md` | Cache CachedTileProvider instance in TileCacheService |
| `parser-utility-deduplication.md` | Move _computeDistanceKm/_stripExtension to map_utils.dart |
| `weather-data-pure-dart.md` | Remove Flutter/IconData dependency from WeatherData model |
| `package-name-constant.md` | kPackageName constant; remove tile URL duplication |
| `tile-url-constants-consolidation.md` | Tile URLs consolidated in TilePreferenceService |
| `hive-box-ownership.md` | imported_trails box opened only by ImportedTrailRepository |
| `intent-handler-error-reporting.md` | debugPrint + onError callback for intent parse/save failures |
| `repository-dead-code-removal.md` | Remove dead saveFromHikeRecord method |
| `homepage-dispose-lifecycle.md` | cancelStream() called from _HomePageState.dispose() |
| `about-animation-cleanup.md` | HikerAnimation re-enabled on AboutScreen |
| `lint-rules-improvement.md` | Additional lint rules in analysis_options.yaml |
| `app-version-service.md` | AppInfoService singleton replaces cachedAppVersion global |
| `trails-stable-id-comparison.md` | OsmTrail selection uses stable UUID string comparison |
| `trail-preview-bounds-cache.md` | _TrailPreviewPanel bounds/centroid cached as late final |
| `track-screen-unused-icon-param.md` | Remove unused icon parameter from _buildTile |
| `tile-cache-store-migration.md` | DEFERRED: dio_cache_interceptor_db_store migration (no pub.dev replacement yet) |
| `guided-hike-start.md` | Start guided hike from Trails screen with green polyline on Map |
| `remove-hiker-animation.md` | Delete hiker animation; unify AboutContent; splash shows version centred |
| `about-content-true-center.md` | True-center icon+info on Splash and About via Center widget |
| `trails-viewmodel-extraction.md` | DEFERRED: TrailsScreen ViewModel extraction (large refactor) |
| `path-simplification.md` | SUPERSEDED by path-simplification-dp.md |
| `map-attribution-missing-screens.md` | Add RichAttributionWidget to HikeDetailScreen, TrailMapScreen, and TrailsScreen (Implemented) |
| `map-attribution.md` | Reusable MapAttributionWidget at top-left replacing RichAttributionWidget on HikeDetailScreen, TrailMapScreen, and TrailsScreen |
| `gps-precision-improvement.md` | Accuracy gate (drop fixes > 30 m), bestForNavigation mode, accuracy tile on Track screen |
| `map-attribution-map-screen.md` | MapAttributionWidget on MapScreen replacing RichAttributionWidget |
| `splash-version-visibility.md` | Fix version blank on splash screen: setState after AppInfoService.init() before navigation |
| `gps-accuracy-mode-high.md` | Change recording GPS stream from bestForNavigation to high accuracy to reduce battery drain |
| `weather-service-error-logging.md` | Add debugPrint to WeatherService catch blocks to distinguish network vs parse failures |
| `trail-preview-bounds-fix.md` | Promote _bounds/_centroid getters to late final fields in _TrailPreviewPanelState |
| `gpx-kml-parse-isolate.md` | Wrap GPX/KML parse calls in compute() to prevent main-isolate jank on large files |
| `haversine-pure-dart.md` | Replace Geolocator.distanceBetween with pure-Dart Haversine in computeDistanceKm |
| `trail-osmid-collision-fix.md` | Replace osmId hash-based trail selection with UUID string comparison to prevent collisions |
| `recording-gap-detection.md` | Detect GPS signal gaps > 30 s; insert NaN sentinel markers; split polyline into segments on map and detail screens |
| `recording-time-interval.md` | Add 5 s time-based sampling interval (Android AndroidSettings) alongside 3 m distance filter to capture slow movement and tight switchbacks |
| `recording-accuracy-adaptive.md` | Buffer poor-quality fixes for up to 15 s; use best buffered fix on recovery; insert gap marker on timeout (depends on recording-gap-detection.md) |
| `gps-recording-density.md` | Reduce distance filter to 1 m, time interval to 2 s, and add heading-change-triggered sampling to capture roundabouts and switchbacks faithfully |
| `splash-version-fix.md` | Definitive fix for version blank on splash: await endOfFrame after setState so rebuild is painted before navigation |
| `android-auto-screen.md` | Android Auto screen: compass, lat/lon/altitude, and live OSM tile map via native CarAppService + EventChannel bridge |
| `satellite-map-view.md` | Extend tile toggle to three-way cycle: OSM → Topo → Satellite → OSM using Esri World Imagery (free, no API key) |
| `path-simplification-dp.md` | Douglas-Peucker path simplification at save time: pure-Dart, NaN-gap-aware, epsilon = 3 m, applied once in stopRecording() |
| `android-auto-visibility-fix.md` | Fix app not appearing in Android Auto: move setSurfaceCallback to onGetTemplate(), add Unknown sources step, move MethodChannel handler to FlutterPlugin |
| `analytics-screen.md` | Analytics screen: date range filter, summary metrics grid, personal bests, streaks, Distance by Month / Day of Week / Distribution bar charts |
| `log-screen-sort-order.md` | Sort toggle (newest/oldest first) in Log screen app bar; persisted via SharedPreferences |
| `trails-screen-sort-order.md` | Sort toggle (A → Z / Z → A) in Trails screen normal-mode app bar; persisted via SharedPreferences |
