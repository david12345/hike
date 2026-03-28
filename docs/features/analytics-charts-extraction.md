# analytics-charts-extraction.md

## User Story

As a developer maintaining the Hike app, I want the chart widgets in the Analytics screen to live in their own file, so that `analytics_screen.dart` is shorter and the chart code is easy to find and modify independently.

## Background / Problem

Analysis report item **M6 (part 1)**.

`lib/screens/analytics_screen.dart` is 1 022 lines. Three private chart widget classes — `_MonthlyDistanceChart`, `_DayOfWeekChart`, and `_DistributionChart` — each contain 60–80 lines of nested `BarChartData` and `fl_chart` configuration. These widgets have no state or logic of their own beyond data display; they are pure rendering widgets that accept data parameters and return a chart. They are ideal candidates for extraction into a dedicated widgets file.

## Requirements

1. Create `lib/widgets/analytics_charts.dart`.
2. Move `_MonthlyDistanceChart`, `_DayOfWeekChart`, and `_DistributionChart` from `analytics_screen.dart` into `analytics_charts.dart`.
3. The moved classes remain private (`_`) within their new file — they are not part of a public API.
4. `analytics_screen.dart` imports `analytics_charts.dart` and references the classes as before.
5. No logic changes to the chart widgets themselves — this is a pure move.
6. The new file must have its own imports (do not rely on transitive imports from `analytics_screen.dart`).

## Non-Goals

- Making the chart classes public or reusable outside the Analytics screen.
- Changing the chart data model or `AnalyticsStats` structure.
- Extracting non-chart private widgets from `analytics_screen.dart` (out of scope for this spec).

## Design / Implementation Notes

**New file:** `lib/widgets/analytics_charts.dart`

**Files to touch:**
- `lib/screens/analytics_screen.dart` — remove the three class bodies; add import.
- `lib/widgets/analytics_charts.dart` — new file with the three classes and all their required imports (`fl_chart`, `flutter/material.dart`, etc.).

**After the move, `analytics_screen.dart` should be approximately 700–800 lines** (down from 1 022), with the remaining private widgets, the screen scaffold, and the filter UI still in place.

## Acceptance Criteria

- [ ] `lib/widgets/analytics_charts.dart` exists and contains all three chart classes.
- [ ] `lib/screens/analytics_screen.dart` contains no definitions of `_MonthlyDistanceChart`, `_DayOfWeekChart`, or `_DistributionChart`.
- [ ] The Analytics screen renders all three charts correctly after the move.
- [ ] `flutter analyze` reports zero issues.
- [ ] `analytics_screen.dart` line count is reduced by at least 150 lines.
