# unit-tests-pure-dart.md

## User Story

As a developer maintaining the Hike app, I want unit tests for the core pure-Dart logic, so that I can refactor path simplification, analytics aggregation, and file parsing with confidence that I have not broken correctness.

## Background / Problem

Analysis report item **M8**.

`test/widget_test.dart` contains a single boilerplate counter test. There is zero test coverage for:
- GPS path simplification (`PathSimplifier` / `path_simplifier.dart`).
- Analytics aggregation (`AnalyticsService.compute()`).
- GPX parsing (`GpxParser`).
- KML parsing (`KmlParser`).

These are all pure-Dart classes with no Flutter dependencies, meaning they can be tested in plain `dart test` without a device, emulator, or widget tree. They are also the most likely to silently regress: a wrong Douglas-Peucker epsilon, a streak-counting off-by-one, or a malformed GPX element would produce wrong results with no visible error.

## Requirements

1. Create `test/path_simplifier_test.dart` with tests for `PathSimplifier`:
   - A straight line of N points simplifies to 2 points (start + end) at any epsilon > 0.
   - A single right-angle turn at the midpoint is preserved when the deflection exceeds epsilon.
   - NaN sentinel values are preserved through simplification (gap markers must not be dropped).
   - An empty list returns an empty list.
   - A list of 1 or 2 points is returned unchanged.
2. Create `test/analytics_service_test.dart` with tests for `AnalyticsService.compute()`:
   - Total distance, total hikes, total duration are correctly summed.
   - Longest streak is correctly calculated for a simple sequence.
   - Monthly distance grouping is correct for hikes spanning a month boundary.
   - An empty hike list returns zeroed stats without throwing.
   - Filter by date range correctly excludes hikes outside the range.
3. Create `test/gpx_parser_test.dart` with tests for `GpxParser`:
   - A minimal valid GPX 1.1 string with one `<trkpt>` is parsed to one `ImportedTrail` with one `LatLng`.
   - Multiple tracks in one GPX file produce multiple `ImportedTrail` objects.
   - A `<trkpt>` missing `lat` or `lon` attributes is skipped without throwing.
   - An empty string throws a `FormatException` or returns an empty list (document the expected behaviour).
4. Create `test/kml_parser_test.dart` with tests for `KmlParser`:
   - A minimal KML string with one `<Placemark>` and `<LineString>` is parsed to one `ImportedTrail`.
   - Coordinate strings with extra whitespace are handled correctly.
   - An empty string throws or returns empty (document expected behaviour).
5. All test files use only `package:test/test.dart` — no Flutter test utilities.
6. All tests pass with `flutter test` (or `dart test test/<file>_test.dart`).

## Non-Goals

- Widget tests or integration tests.
- Mocking GPS hardware or Hive storage.
- 100% line coverage — the goal is coverage of the key algorithmic paths.
- Testing `WeatherService` HTTP calls (requires mocking).

## Design / Implementation Notes

**Test data:** use inline string literals for GPX/KML XML. Do not load test fixtures from disk (keeps tests self-contained).

**`HikeRecord` dependency in analytics tests:** `AnalyticsService.compute()` accepts `List<HikeRecord>`. `HikeRecord` is a Hive model — instantiate it directly without registering the adapter (Hive adapters are only needed for persistence, not for plain object creation).

**Running tests:**
```bash
flutter test test/path_simplifier_test.dart
flutter test test/analytics_service_test.dart
flutter test test/gpx_parser_test.dart
flutter test test/kml_parser_test.dart
```

**Relationship:** implementing this spec after `analytics-isolate-compute.md` and `analytics-viewmodel.md` ensures the `AnalyticsService` function signature is stable.

## Acceptance Criteria

- [ ] All four test files exist in `test/`.
- [ ] `flutter test` passes with zero failures.
- [ ] `PathSimplifier` NaN-preservation test passes.
- [ ] `AnalyticsService` empty-list test passes without throwing.
- [ ] `GpxParser` and `KmlParser` tests parse at least one valid fixture string successfully.
- [ ] No Flutter imports in any of the four test files.
