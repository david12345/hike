# hike-record-latlng-parity-guard.md

## User Story

As a hiker, I want the app to recover gracefully if a hike record was partially written during a crash, so that I can still view my other hikes without the app crashing with an index error.

## Background / Problem

Analysis report item **C2**.

`HikeRecord` stores GPS coordinates as two independent `List<double>` fields — `latitudes` and `longitudes` — in the Hive box (`lib/models/hike_record.dart`, lines 5–9). Hive box writes are not transactional. A crash between writing `latitudes` and writing `longitudes` leaves the two lists at different lengths. `HikeDetailScreen.initState()` subsequently zips the two lists using `latitudes.length` without verifying that `longitudes.length` matches, causing an `IndexError` crash every time the user taps the affected hike record.

## Requirements

1. In `HikeDetailScreen.initState()`, before building `_route`, add a length-parity check: `if (hike.latitudes.length != hike.longitudes.length)`.
2. If lengths differ, truncate both lists to `min(hike.latitudes.length, hike.longitudes.length)` before further processing.
3. Log a warning with `debugPrint` when truncation occurs, including the hike ID and both lengths, so the corruption event is visible in logs.
4. The fix must be defensive only — it must not modify the persisted `HikeRecord` in Hive.
5. After truncation, the screen must render normally with the available (possibly shorter) route.
6. Consider applying the same guard in `LogScreen` if it accesses the coordinate lists directly.

## Non-Goals

- Making Hive writes transactional (not feasible with the current Hive version).
- Attempting to repair the corrupted record automatically by back-filling missing coordinates.
- Adding a migration that scans all stored hike records on startup.

## Design / Implementation Notes

**Files to touch:**
- `lib/screens/hike_detail_screen.dart` — add guard at the top of `initState()` before building `_route`.

Code sketch:

```dart
@override
void initState() {
  super.initState();
  final lats = widget.hike.latitudes;
  final lons = widget.hike.longitudes;
  if (lats.length != lons.length) {
    debugPrint(
      '[HikeDetail] lat/lon length mismatch for hike ${widget.hike.id}: '
      '${lats.length} lats vs ${lons.length} lons — truncating to min.',
    );
    // Work on a truncated view; do not mutate the Hive object.
    final n = math.min(lats.length, lons.length);
    _route = List.generate(n, (i) => LatLng(lats[i], lons[i]));
  } else {
    _route = List.generate(lats.length, (i) => LatLng(lats[i], lons[i]));
  }
  // ... rest of initState
}
```

Import `dart:math` for `min`.

## Acceptance Criteria

- [ ] A `HikeRecord` with mismatched lat/lon list lengths (simulated in a test or manually crafted) does not crash `HikeDetailScreen`.
- [ ] `debugPrint` output is visible in the debug console when truncation occurs.
- [ ] A `HikeRecord` with matching lengths behaves identically to the current implementation.
- [ ] The Hive-persisted record is unchanged after opening the detail screen.
- [ ] `flutter analyze` reports zero issues after the change.
