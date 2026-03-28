# brand-green-constant.md

## User Story

As a developer maintaining the Hike app, I want the primary brand colour to be defined in exactly one place, so that a colour change only requires editing a single line.

## Background / Problem

Analysis report item **M5**.

The value `Color(0xFF2E7D32)` (Material green 800, the app's primary brand colour) appears in at least two places:

- `lib/screens/analytics_screen.dart` line 686: `const _kBarColor = Color(0xFF2E7D32)`.
- `lib/main.dart`: `ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32))`.

These are the same colour. If the brand colour is ever changed, both sites must be updated. `lib/utils/constants.dart` already exists and contains other app-wide constants (`kFallbackLocation`, `kOsmTileUrl`, etc.) — it is the correct home for this constant.

## Requirements

1. Add `const Color kBrandGreen = Color(0xFF2E7D32);` to `lib/utils/constants.dart`.
2. Replace the `Color(0xFF2E7D32)` literal in `lib/main.dart` with `kBrandGreen`.
3. Replace `const _kBarColor = Color(0xFF2E7D32)` in `lib/screens/analytics_screen.dart` with a reference to `kBrandGreen` (either directly or via a local alias `const _kBarColor = kBrandGreen`).
4. Search the entire codebase for any other `0xFF2E7D32` occurrences and replace them with `kBrandGreen`.
5. Add the necessary import of `constants.dart` in any file that did not already import it.

## Non-Goals

- Changing the brand colour value itself.
- Moving other colour constants into `constants.dart` (out of scope for this spec).
- Introducing a theme extension or design-token system.

## Design / Implementation Notes

**Files to touch:**
- `lib/utils/constants.dart` — add `kBrandGreen`.
- `lib/main.dart` — replace literal.
- `lib/screens/analytics_screen.dart` — replace `_kBarColor` definition.
- Any other file identified by `grep -r "0xFF2E7D32" lib/`.

**Import:** `constants.dart` is already imported in many files; check each target file individually.

## Acceptance Criteria

- [ ] `lib/utils/constants.dart` contains `kBrandGreen`.
- [ ] `grep -r "0xFF2E7D32" lib/` returns zero results.
- [ ] The app's colour scheme and analytics bar colour are visually unchanged.
- [ ] `flutter analyze` reports zero issues.
