# user-preferences-service.md

## User Story

As a developer maintaining the Hike app, I want all `SharedPreferences` access to go through a single service initialised at startup, so that preference keys are defined in one place, async loading never races with widget `initState`, and preferences can be read synchronously from any widget.

## Background / Problem

Analysis report item **H2**.

`SharedPreferences.getInstance()` is called independently in three different screens:
- `lib/screens/log_screen.dart` lines 27–39 (sort order preference).
- `lib/screens/analytics_screen.dart` lines 105–156 (filter preset and custom date range).
- `lib/screens/trails_screen.dart` lines 82–93 (sort order preference).

Each screen performs its own async load in `initState`, duplicating the load/save pattern and creating async state management at the widget layer. There is no central registry of preference keys, making key typos or collisions possible. `TilePreferenceService` already demonstrates the correct pattern (ChangeNotifier singleton, initialised at app startup).

## Requirements

1. Create `lib/services/user_preferences_service.dart` containing a `UserPreferencesService` singleton that extends or uses `ChangeNotifier`.
2. The service is initialised once in `SplashScreen.initState()` alongside `HikeService.init()` and `TileCacheService`.
3. The service exposes typed, synchronous getters and setters for every preference currently scattered across the three screens:
   - `LogSortOrder logSortOrder` (get/set)
   - `TrailsSortOrder trailsSortOrder` (get/set)
   - `FilterPreset analyticsFilterPreset` (get/set)
   - `DateTimeRange? analyticsCustomRange` (get/set)
4. All preference keys are defined as private constants inside `UserPreferencesService`.
5. Setters persist the new value to `SharedPreferences` asynchronously (fire-and-forget) and call `notifyListeners()`.
6. After the service is initialised, all reads are synchronous (backed by in-memory fields) — no widget need `await` a preference load.
7. `LogScreen`, `AnalyticsScreen`, and `TrailsScreen` are updated to read from and write to `UserPreferencesService` instead of calling `SharedPreferences.getInstance()` directly.
8. The service instance is accessible as a singleton (e.g. `UserPreferencesService.instance`) following the `TilePreferenceService` pattern.

## Non-Goals

- Migrating `TilePreferenceService` tile-mode preference into `UserPreferencesService` (keep tile preferences separate as they have a different lifecycle).
- Introducing a full preferences framework (e.g. `flutter_secure_storage`, `hydrated_bloc`).
- Encrypting stored preferences.

## Design / Implementation Notes

**New file:** `lib/services/user_preferences_service.dart`

**Files to touch:**
- `lib/screens/splash_screen.dart` — add `UserPreferencesService.init()` to the `Future.wait` list.
- `lib/screens/log_screen.dart` — remove `SharedPreferences` import and `initState` load; read from service.
- `lib/screens/analytics_screen.dart` — same.
- `lib/screens/trails_screen.dart` — same.

**Pattern reference:** `lib/services/tile_preference_service.dart`.

**Enum types:** define `LogSortOrder` and `TrailsSortOrder` enums (e.g. in the service file or in a shared `lib/models/preferences.dart`) if they are not already defined.

## Acceptance Criteria

- [ ] `lib/services/user_preferences_service.dart` exists with all four preference fields.
- [ ] `SplashScreen` initialises `UserPreferencesService` before navigating to `HomePage`.
- [ ] `LogScreen`, `AnalyticsScreen`, and `TrailsScreen` contain no `SharedPreferences.getInstance()` calls.
- [ ] Preference values survive an app restart (verified manually: set a sort order, kill and relaunch the app, confirm the sort order is restored).
- [ ] All preference keys are defined as string constants in `UserPreferencesService`; no literal key strings appear in screen files.
- [ ] `flutter analyze` reports zero issues.
