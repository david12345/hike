# segments-cache.md

## User Story

As a hiker reviewing a past hike, I want the detail map to render smoothly without redundant computation, so that scrolling the stats panel and interacting with the map does not cause unnecessary work.

## Background / Problem

Analysis report item **H5**.

`segmentsFromPoints()` (which splits a polyline at NaN sentinel markers into segments) is called inside `build()` in two places:

- `lib/screens/hike_detail_screen.dart` line 113: the route is immutable after `initState()` — calling `segmentsFromPoints()` on every parent rebuild is pure waste.
- `lib/screens/map_screen.dart` line 109: called inside the `ListenableBuilder` that fires on every GPS fix during recording, meaning it re-iterates the full growing point list multiple times per second at the 1 m / 2 s recording density.

## Requirements

1. **`HikeDetailScreen`:** compute `segmentsFromPoints(_route)` once in `initState()` and store the result in a `late final List<List<LatLng>> _segments` field. Replace the `build()` call with `_segments`.
2. **`MapScreen`:** compute `segmentsFromPoints(points)` inside the `_onTrackingChanged` callback (or equivalent method that fires when the tracking state updates) and store the result in a `List<List<LatLng>> _segments` instance field. Replace the `build()` call with `_segments`.
3. The `MapScreen` `_segments` field must be initialised to an empty list (not `late final`) because the point list grows during recording.
4. Both cached fields must be recomputed if the underlying data changes (for `HikeDetailScreen` it never changes; for `MapScreen` it changes on every `_onTrackingChanged` call).
5. No public API changes — this is a purely internal performance optimisation.

## Non-Goals

- Caching segments globally across screen instances.
- Debouncing `_onTrackingChanged` calls (that is a separate concern).
- Changing the `segmentsFromPoints()` function signature or behaviour.

## Design / Implementation Notes

**Files to touch:**
- `lib/screens/hike_detail_screen.dart` — add `late final List<List<LatLng>> _segments;`, populate in `initState()` after `_route` is built.
- `lib/screens/map_screen.dart` — add `List<List<LatLng>> _segments = [];`, update in `_onTrackingChanged`.

**Related:** `M4` (`hike-detail-point-count-cache.md`) caches `pointCount` in the same `initState()` pass — both changes can be applied together.

**`HikeDetailScreen` sketch:**
```dart
late final List<List<LatLng>> _segments;

@override
void initState() {
  super.initState();
  // ... existing _route build ...
  _segments = segmentsFromPoints(_route);
}
```

**`MapScreen` sketch:**
```dart
List<List<LatLng>> _segments = [];

void _onTrackingChanged() {
  final points = TrackingState.instance.recordedPoints
      .map((p) => LatLng(p.latitude, p.longitude))
      .toList();
  setState(() {
    _segments = segmentsFromPoints(points);
  });
}
```

## Acceptance Criteria

- [ ] `HikeDetailScreen.build()` contains no call to `segmentsFromPoints()`.
- [ ] `MapScreen.build()` contains no call to `segmentsFromPoints()`.
- [ ] Opening a hike detail with 5 000 recorded points does not produce repeated `segmentsFromPoints` calls in the Flutter DevTools performance timeline during map interaction.
- [ ] The polyline on both screens renders identically before and after the change.
- [ ] `flutter analyze` reports zero issues.
