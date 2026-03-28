# trail-card-extraction.md

## User Story

As a developer maintaining the Hike app, I want the trail list card widget to live in its own class, so that `trails_screen.dart` is shorter and the card layout is easier to modify and test independently.

## Background / Problem

Analysis report item **M6 (part 2)**.

`lib/screens/trails_screen.dart` is 1 015 lines. The `itemBuilder` for the trails list contains an approximately 200-line inline card builder that handles the trail name, distance, type badge, action buttons (guided hike, preview, export, delete), and selection checkbox. This inline widget has clear boundaries — it receives one `ImportedTrail` and a set of callbacks — making it a straightforward extraction candidate.

## Requirements

1. Extract the trail list card into a private stateless widget class `_TrailCard` within `lib/screens/trails_screen.dart` (same file is acceptable to avoid a circular import), or move it to `lib/widgets/trail_card.dart`.
2. `_TrailCard` accepts parameters for:
   - `ImportedTrail trail`
   - All required callbacks (onTap, onGuidedHike, onPreview, onExport, onDelete, onSelectionToggle, etc.)
   - `bool isSelected` (for multi-select mode)
   - `bool isMultiSelectMode`
3. `_TrailCard` is stateless — no state lives inside it.
4. The `itemBuilder` in `_buildBody` is replaced with a single `_TrailCard(...)` instantiation.
5. No logic changes to the card's callbacks — this is a pure structural extraction.

## Non-Goals

- Moving `_TrailCard` to a shared library used by other screens.
- Extracting `_TrailPreviewPanel` (already specced in `trail-preview-bounds-cache.md`).
- Adding new visual elements to the card.

## Design / Implementation Notes

**Preferred location:** keep `_TrailCard` as a private class in `lib/screens/trails_screen.dart` to avoid adding a new public import. If the file is still too long after other extractions, move it to `lib/widgets/`.

**Parameter interface** (sketch):
```dart
class _TrailCard extends StatelessWidget {
  const _TrailCard({
    required this.trail,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
    required this.onGuidedHike,
    required this.onPreview,
    required this.onExport,
    required this.onDelete,
    required this.onToggleSelect,
  });
  // ...
}
```

## Acceptance Criteria

- [ ] A class named `_TrailCard` exists (in `trails_screen.dart` or `lib/widgets/trail_card.dart`).
- [ ] The `itemBuilder` in `_buildBody` is a single `_TrailCard(...)` call, not an inline widget tree.
- [ ] The trail list renders identically to before (all buttons, badges, selection mode behaviour preserved).
- [ ] `flutter analyze` reports zero issues.
- [ ] `trails_screen.dart` line count is reduced by at least 150 lines.
