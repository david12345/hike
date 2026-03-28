# async-mounted-check.md

## User Story

As a hiker deleting a hike from the log, I want the app to handle the confirmation dialog safely even if I navigate away before confirming, so that the app does not crash with a "widget not mounted" error or attempt to use a disposed `BuildContext`.

## Background / Problem

Analysis report item **M7**.

`lib/screens/log_screen.dart` (lines 96–108) contains a `_delete()` method that calls `HikeService.delete(hike.id)` after `await showDialog(...)`. There is no `if (!mounted) return;` guard between the `await` and the subsequent context use. If the widget is disposed while the dialog is open (e.g. the user navigates away), the `setState` and `ScaffoldMessenger` calls after the `await` will execute against a disposed context, which is a source of runtime errors or leaked state.

## Requirements

1. Add `if (!mounted) return;` immediately after `await showDialog(...)` in `_delete()` in `lib/screens/log_screen.dart`.
2. Audit every other `async` method in `log_screen.dart` that uses `context` after an `await`; add guards where missing.
3. Perform the same audit in `lib/screens/trails_screen.dart` and `lib/screens/hike_detail_screen.dart` — add `if (!mounted) return;` after every `await` that is followed by a `context` use in those files.
4. Do not change any existing logic — only add the guard statements.

## Non-Goals

- Converting `async` widget methods to use explicit `Navigator` keys or route observers.
- Adding mounted checks in service classes (they do not have `BuildContext`).
- Refactoring to avoid async gaps (that would require larger architectural changes).

## Design / Implementation Notes

**Files to touch:**
- `lib/screens/log_screen.dart` — `_delete()` and any other async methods.
- `lib/screens/trails_screen.dart` — audit all async methods.
- `lib/screens/hike_detail_screen.dart` — audit all async methods.

**Pattern:**
```dart
Future<void> _delete(HikeRecord hike) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ...,
  );
  if (!mounted) return;  // <-- add this
  if (confirmed != true) return;
  await HikeService.delete(hike.id);
  if (!mounted) return;  // <-- add after each subsequent await that uses context
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

**Lint note:** enabling the `use_build_context_synchronously` lint rule (part of `analysis-options-strengthen.md`) would catch these gaps automatically in future. Consider enabling it alongside this fix.

## Acceptance Criteria

- [ ] `if (!mounted) return;` appears after every `await showDialog` call in `log_screen.dart`.
- [ ] `if (!mounted) return;` appears after every `await` followed by a `context` use in `trails_screen.dart` and `hike_detail_screen.dart`.
- [ ] No `use_build_context_synchronously` lint warnings appear in the audited files (if the lint rule is enabled).
- [ ] Opening the Log screen, starting a delete, and navigating away before confirming does not produce a Flutter error in the debug console.
- [ ] `flutter analyze` reports zero issues.
