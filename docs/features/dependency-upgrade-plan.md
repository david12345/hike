# dependency-upgrade-plan.md

## User Story

As a developer maintaining the Hike app, I want a clear plan for upgrading the major-version-behind dependencies, so that I can apply each upgrade safely in isolation without breaking the app.

## Background / Problem

Analysis report item **M9**.

Several packages in `pubspec.yaml` are multiple major versions behind their latest stable release:

| Package | Current | Latest at analysis |
|---------|---------|---------------------|
| `flutter_map` | 7.0.2 | 8.2.2 |
| `fl_chart` | 0.70.0 | 1.2.x |
| `geolocator` | 13.x | 14.x |
| `flutter_foreground_task` | 8.x | 9.x |
| `file_picker` | 8.x | 10.x |
| `share_plus` | 10.x | 12.x |

Major version bumps typically contain breaking API changes. Upgrading all at once makes it difficult to isolate regressions. `dio_cache_interceptor_db_store` is discontinued and tracked separately in `tile-cache-store-migration.md`.

## Requirements

This is a **planning and documentation spec**. It defines the upgrade order, the known breaking changes to handle, and the acceptance criteria for each package. Implementation is done in separate commits, one package at a time.

### Upgrade order and notes

1. **`share_plus` 10 → 12**
   - Check CHANGELOG for API changes to `SharePlus.instance.share()` / `ShareResult`.
   - Audit all `share_plus` call sites in `trails_screen.dart` (or `TrailsImportExportService` once extracted).
   - Risk: low — share sheet API is stable.

2. **`file_picker` 8 → 10**
   - Check for changes to `FilePicker.platform.pickFiles()` return type and `FilePickerResult` fields.
   - Audit call sites in `trails_screen.dart` (or `TrailsImportExportService`).
   - Risk: low — core API is stable.

3. **`fl_chart` 0.70 → 1.2**
   - High risk: `fl_chart` 1.x has significant API changes (`BarChartData`, `LineChartData`, touch callback signatures).
   - Extract chart widgets first (`analytics-charts-extraction.md`) to reduce the surface area.
   - Test all three charts (`_MonthlyDistanceChart`, `_DayOfWeekChart`, `_DistributionChart`) visually after upgrade.

4. **`geolocator` 13 → 14**
   - Check for changes to `LocationSettings`, `Position` fields, `GeolocatorPlatform.instance`.
   - Audit `location_service.dart` and `tracking_state.dart`.
   - Run a full recording session after upgrade to confirm no position stream regressions.

5. **`flutter_foreground_task` 8 → 9**
   - Check for changes to `FlutterForegroundTask.startService()`, `TaskHandler` interface, notification config.
   - Audit `foreground_tracking_service.dart`.
   - Test background recording end-to-end after upgrade.

6. **`flutter_map` 7 → 8**
   - Highest risk: `flutter_map` 8.x breaks `TileLayer`, `PolylineLayer`, `MarkerLayer`, `MapOptions`, and `MapController` APIs.
   - Also requires updating `flutter_map_cache` to a compatible version (check pub.dev).
   - Upgrade last, after all other packages are stable.
   - Regression test: all four map screens (Map, Hike Detail, Trail Map, Trails preview).

### Per-upgrade process

For each package:
1. Update the version constraint in `pubspec.yaml`.
2. Run `flutter pub get`.
3. Fix all `dart analyze` errors.
4. Run `flutter build apk --release` to confirm no build errors.
5. Manually test the affected features.
6. Commit as a standalone commit: `"chore: upgrade <package> to vX.Y.Z"`.

## Non-Goals

- Upgrading `hive` or `hive_flutter` (breaking change would require a migration path for stored data — out of scope).
- Upgrading `dio_cache_interceptor_db_store` (tracked in `tile-cache-store-migration.md`).
- Automated upgrade tooling (dependabot, renovate).

## Design / Implementation Notes

**No code changes in this spec.** This is a planning document. Each upgrade is a separate implementation task.

**Checking breaking changes:**
```bash
# View changelog for a package
dart pub changelog <package>
# Or visit pub.dev/<package>/changelog
```

**After each upgrade, run:**
```bash
flutter analyze
flutter build apk --release
```

## Acceptance Criteria

- [ ] This spec file exists in `docs/features/dependency-upgrade-plan.md` as a reference.
- [ ] Each of the six packages is upgraded in a separate commit, in the order specified above.
- [ ] After all upgrades, `flutter analyze` reports zero issues.
- [ ] After all upgrades, a full end-to-end smoke test passes: record a hike, save it, view it on the detail map, import a GPX trail, export it.
- [ ] `pubspec.yaml` contains no package version constraint that is more than one major version behind the current stable release at the time of upgrade.
