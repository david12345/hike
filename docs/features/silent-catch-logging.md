# silent-catch-logging.md

## User Story

As a developer debugging the Hike app in the field, I want every caught exception to emit at least a log line, so that I can identify silent failures in import, pedometer, and background service code without attaching a debugger.

## Background / Problem

Analysis report item **H6**.

Several `catch` blocks across the codebase swallow exceptions without logging:

- `lib/screens/trails_screen.dart` lines 211–214: `FormatException` on GPX/KML import is caught silently. The user sees nothing; the import simply does not happen.
- `lib/services/hike_recording_controller.dart` lines 256–259: pedometer probe catch. A false-negative here is persisted to `SharedPreferences`, silently disabling step counting for the lifetime of the install.
- `lib/services/hike_recording_controller.dart` lines 362–365 and 541–544: pedometer `onError` callbacks.
- `lib/services/hike_recording_controller.dart` lines 447–449: foreground service stop catch.

The pedometer persistence case is especially dangerous: a transient platform error during the probe can permanently disable step counting, with no log trace to indicate why.

## Requirements

1. Every `catch` block identified above must emit a `debugPrint` containing:
   - The component name (e.g. `[TrailsImport]`, `[PedometerProbe]`, `[ForegroundService]`).
   - The exception type and message (`$e` or `e.runtimeType`).
   - A brief description of the consequence (e.g. "step counting disabled for this install").
2. In the pedometer-probe catch (lines 256–259), add a comment explaining the `SharedPreferences` persistence risk so future maintainers understand the severity.
3. Do not change any existing error-handling logic — only add `debugPrint` calls.
4. For `trails_screen.dart`, ensure the existing user-facing error feedback (snack bar or dialog, if any) is preserved; if none exists, a `debugPrint` alone is sufficient for this spec (a snack bar improvement belongs in `trails-import-export-service.md`).
5. Apply the same `debugPrint` standard to any other silent catch blocks found during implementation that were not listed in the analysis report.

## Non-Goals

- Introducing a crash-reporting service (Firebase Crashlytics, Sentry, etc.).
- Changing error recovery logic.
- Adding `debugPrint` to intentionally silent no-op catches (e.g. `catch (_) {}`  around UI convenience calls where failure is expected and harmless).

## Design / Implementation Notes

**Files to touch:**
- `lib/screens/trails_screen.dart` — lines 211–214.
- `lib/services/hike_recording_controller.dart` — lines 256–259, 362–365, 447–449, 541–544.

**Template:**
```dart
} catch (e) {
  debugPrint('[PedometerProbe] probe failed: $e — '
      'step counting will be disabled for this install');
  // existing: _pedometerAvailable = false; ...
}
```

## Acceptance Criteria

- [ ] All four locations listed in the analysis report have a `debugPrint` call inside their `catch` block.
- [ ] The debug console shows a log line when a simulated parse error occurs during GPX import.
- [ ] The debug console shows a log line when the pedometer probe fails (simulate by running on a device that reports no pedometer).
- [ ] No `catch` block in the two target files silently swallows an exception without a `debugPrint`.
- [ ] `flutter analyze` reports zero issues.
