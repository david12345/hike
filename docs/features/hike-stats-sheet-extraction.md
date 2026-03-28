# hike-stats-sheet-extraction.md

## User Story

As a developer maintaining the Hike app, I want the hike statistics panel to be a self-contained widget, so that `hike_detail_screen.dart` is shorter and the stats layout can be evolved without navigating a large build method.

## Background / Problem

Analysis report item **M6 (part 3)**.

`lib/screens/hike_detail_screen.dart` contains a `DraggableScrollableSheet` whose builder closure is a large inline widget tree rendering all the hike statistics (name, date, distance, duration, average speed, point count, altitude info, step count, calories). This inline builder makes the `build()` method harder to read and the stats layout harder to modify in isolation.

## Requirements

1. Extract the `DraggableScrollableSheet` builder content into a private stateless widget `_HikeStatsSheet`.
2. `_HikeStatsSheet` accepts the `HikeRecord` (or the individual stats fields) as constructor parameters.
3. `HikeDetailScreen` replaces the inline builder content with a single `_HikeStatsSheet(hike: widget.hike)` call.
4. `_HikeStatsSheet` is stateless — it has no local state beyond what is passed in.
5. The `_pointCount` cached value (from `hike-detail-point-count-cache.md`) is passed as a parameter rather than recomputed inside `_HikeStatsSheet`.
6. No logic changes to the stats display — this is a pure structural extraction.

## Non-Goals

- Moving `_HikeStatsSheet` to a shared widget library.
- Changing the stats displayed (adding or removing fields).
- Changing the `DraggableScrollableSheet` sizing parameters.

## Design / Implementation Notes

**Location:** private class `_HikeStatsSheet` at the bottom of `lib/screens/hike_detail_screen.dart`.

**Constructor sketch:**
```dart
class _HikeStatsSheet extends StatelessWidget {
  const _HikeStatsSheet({
    required this.hike,
    required this.pointCount,
  });

  final HikeRecord hike;
  final int pointCount;
  // ...
}
```

**`DraggableScrollableSheet` after extraction:**
```dart
DraggableScrollableSheet(
  // ... sizing params unchanged ...
  builder: (context, controller) => _HikeStatsSheet(
    hike: widget.hike,
    pointCount: _pointCount,
  ),
)
```

## Acceptance Criteria

- [ ] A class named `_HikeStatsSheet` exists in `hike_detail_screen.dart`.
- [ ] The `DraggableScrollableSheet` builder contains only a `_HikeStatsSheet(...)` instantiation, not an inline widget tree.
- [ ] All hike statistics render correctly after the extraction.
- [ ] The draggable sheet behaviour (min/max size, scroll controller) is unchanged.
- [ ] `flutter analyze` reports zero issues.
