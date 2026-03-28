# Feature Spec: Splash Screen Version Visibility Fix

**Version target:** 1.31.0
**Status:** Proposed
**Date:** 2026-03-28

---

## User Story

As a hiker launching the app, I want to see the version number on the splash screen so that I can confirm at a glance which build is installed, without having to navigate to the About tab.

---

## Problem

The version string is blank on the splash screen. The About tab shows the correct version. Both screens use identical code:

```dart
AboutContent(version: AppInfoService.instance.version)
```

The difference is timing.

### Root Cause

`AppInfoService.instance.version` is initialised to `''` and is populated only when `AppInfoService.init()` completes. That call is placed inside `Future.wait(...)` inside `_SplashScreenState._initAndNavigate()`, which runs asynchronously after `initState()` returns.

Flutter calls `build()` synchronously on the first frame, before `_initAndNavigate()` has had any opportunity to `await`. At that point `AppInfoService.instance.version` is still `''`, so `AboutContent` renders an empty string where the version should appear.

When `AppInfoService.init()` finishes (together with the minimum 2-second delay), `_initAndNavigate()` navigates away immediately with `Navigator.pushReplacement`. No `setState` is called between the version becoming available and the navigation, so `build()` is never re-invoked with the populated version string. The version stays blank for the entire visible duration of the splash screen.

`AboutScreen` is only ever constructed after the splash `Future.wait` resolves and `HomePage` is on the navigation stack. By then `AppInfoService.instance.version` already holds the correct string, so the About tab has always shown it correctly.

### Why This Was Not Caught Earlier

The `AppInfoService` singleton and `AboutContent` were introduced in separate incremental passes. The race was not observable in debug builds on fast devices where `PackageInfo.fromPlatform()` resolves in a few milliseconds — but the first-frame `build()` is always called before any async work completes, making the race deterministic regardless of device speed.

---

## Requirements

| # | Requirement |
|---|-------------|
| 1 | The version string must be visible on the splash screen for its full display duration. |
| 2 | The version string displayed must match the value returned by `AppInfoService.instance.version` after `init()` completes. |
| 3 | `_SplashScreenState.build()` must be re-invoked after `AppInfoService.init()` completes and before navigation. |
| 4 | The minimum 2-second splash delay and all other existing initialisation (`HikeService.init`, `ImportedTrailRepository.init`, etc.) must be preserved. |
| 5 | No new services, files, or parameters may be introduced. |
| 6 | The fix must not affect `AboutScreen` — it already works correctly. |

---

## Implementation

### File to change

`/home/dealmeida/hike/lib/screens/splash_screen.dart`

### Change

After `Future.wait(...)` completes and before the crash-recovery check, call `setState(() {})` to trigger a rebuild. At that moment `AppInfoService.instance.version` holds the real version string, so the re-invoked `build()` passes it to `AboutContent` and the version appears on screen for the remaining visible duration (typically near-zero because navigation follows immediately, but still visible if the user has slow storage or a recovery dialog appears).

**Before** (in `_initAndNavigate`, after the `Future.wait` closes):

```dart
if (!mounted) return;

// Check for an interrupted recording.
final unfinished = HikeService.findUnfinished();
```

**After:**

```dart
if (!mounted) return;
setState(() {}); // version is now available; repaint before navigating

// Check for an interrupted recording.
final unfinished = HikeService.findUnfinished();
```

This single `setState` call schedules one additional frame. Because `AboutContent` is a `StatelessWidget` that reads `AppInfoService.instance.version` at build time, the new frame displays the correct version string. The subsequent `Navigator.pushReplacement` call is issued in the same microtask queue iteration and the transition animation carries the updated frame.

### Why this is the minimal fix

- No new `ValueNotifier`, `StreamBuilder`, or `FutureBuilder` is needed.
- `AboutContent` already accepts the version as a constructor argument; no widget changes are required.
- `AppInfoService` already exposes `version` as a plain getter; no service changes are required.
- The pattern (`setState` to rebuild after async init completes, then navigate) is the standard Flutter idiom for splash screens that display data resolved during init.

---

## Acceptance Criteria

- [ ] The version string (e.g. "v1.31.0") is visible on the splash screen on a physical Android device.
- [ ] The version string is visible on the splash screen when a crash-recovery dialog appears (the dialog extends the splash duration, making the version clearly readable).
- [ ] The version string on the splash screen matches the version on the About tab.
- [ ] `flutter analyze` reports no new warnings or errors.
- [ ] No regression: About tab still shows the correct version.
- [ ] No regression: crash-recovery dialog still appears when an unfinished hike is found.
- [ ] No regression: the minimum 2-second splash delay is preserved.
