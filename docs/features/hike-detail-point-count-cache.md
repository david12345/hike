# hike-detail-point-count-cache.md

## User Story

As a hiker reviewing a past hike on the detail screen, I want the app to avoid redundant computation on every frame, so that the stats panel and map remain fluid even for long hikes with thousands of recorded points.

## Background / Problem

Analysis report item **M4**.

`lib/screens/hike_detail_screen.dart` (lines 76–78) computes:

```dart
final pointCount = widget.hike.latitudes.where((lat) => !lat.isNaN).length;
```

inside `build()`. This filters the full `latitudes` list on every call to `build()`, which fires on every parent rebuild, every `DraggableScrollableSheet` drag, and every tile preference change. The `_route` and `_realPoints` fields are already cached as `late final` in `initState()` — `pointCount` should be too.

## Requirements

1. In `HikeDetailScreen.initState()`, compute `pointCount` once and store it as `late final int _pointCount`.
2. Replace the `build()` inline computation with `_pointCount`.
3. No logic change — the count must remain the number of non-NaN latitude values (i.e. real GPS points, excluding gap sentinels).

## Non-Goals

- Caching any other derived values in this ticket (segments are covered by `segments-cache.md`).
- Changing the NaN-sentinel mechanism.

## Design / Implementation Notes

**Files to touch:**
- `lib/screens/hike_detail_screen.dart` only.

This is a one-line addition in `initState()` and a one-word substitution in `build()`.

```dart
// initState():
_pointCount = widget.hike.latitudes.where((lat) => !lat.isNaN).length;

// build():
// Replace: widget.hike.latitudes.where((lat) => !lat.isNaN).length
// With:    _pointCount
```

**Related:** if `hike-record-latlng-parity-guard.md` is implemented first, `_pointCount` should be computed from the (possibly truncated) `_route` list length for consistency, rather than re-scanning `widget.hike.latitudes`.

## Acceptance Criteria

- [ ] `HikeDetailScreen.build()` contains no `.where((lat) => !lat.isNaN).length` computation.
- [ ] `_pointCount` is a `late final int` field populated in `initState()`.
- [ ] The point count displayed in the stats panel is correct for hikes with and without NaN gap sentinels.
- [ ] `flutter analyze` reports zero issues.
