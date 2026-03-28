# Feature Spec: Splash & About Screen — Centered Info Block

**Version target:** 1.31.0
**Status:** Proposed
**Date:** 2026-03-28

---

## User Story

As a hiker opening the app or visiting the About tab, I want to see the app
logo, tagline, a link to the issue tracker, the version number, and a contact
email all centered on screen — and be able to tap the link or email to open
them — so that I can quickly find support or report a bug without hunting
through menus.

---

## Problem Statement

`lib/widgets/about_content.dart` already shows the icon, app name, tagline,
GitHub issues URL, and version string. However, two items are missing and one
item requires a behavioral change:

1. **Missing: contact email.** `david.a.ferreira@protonmail.com` is not
   rendered anywhere on either screen.

2. **Non-tappable URLs.** The GitHub issues URL is displayed as plain `Text`.
   Tapping it does nothing. Discoverable links that do nothing are a UX
   problem, particularly for users who want to report a bug.

3. **Subtitle text mismatch.** The current subtitle reads
   `"Essential features for hiking"`. The canonical subtitle per the feature
   request is `"Essential tools for hiking."` (with a full stop).

The two affected screens — `SplashScreen` and `AboutScreen` — both render
`AboutContent` as their `Scaffold.body`, so fixing `AboutContent` fixes both
screens simultaneously.

---

## Requirements

| # | Requirement |
|---|-------------|
| R1 | The info block must display the following five items in order, centered vertically and horizontally: (1) app logo, (2) subtitle, (3) GitHub issues URL, (4) version number, (5) contact email. |
| R2 | The subtitle text must read `"Essential tools for hiking."` (note: "tools", not "features"; trailing full stop). |
| R3 | The GitHub issues URL (`https://github.com/david12345/hike/issues`) must be tappable and open the URL in the device's default browser via `url_launcher`. |
| R4 | The contact email (`david.a.ferreira@protonmail.com`) must be displayed below the version number and must be tappable, launching a mail compose intent via `url_launcher` (`mailto:` scheme). |
| R5 | Both tappable items (URL and email) must be styled to signal interactivity — use a distinct colour such as `Colors.lightBlueAccent` with an `UnderlineDecoration`, keeping the rest of the text white/white54 as today. |
| R6 | The `Center` layout introduced in v1.30.0 must be preserved: no `SafeArea`, no `Spacer`, no additional nesting. `_buildInfoBlock()` returns a shrink-wrapped `Column(mainAxisSize: MainAxisSize.min, ...)` and the `build` method wraps it in `Center`. |
| R7 | `SplashScreen` must not be changed. It already renders `AboutContent(version: ...)` as `Scaffold.body` and requires no modifications. |
| R8 | `AboutScreen` must not be changed. Same reasoning as R7. |
| R9 | `url_launcher` must be added to `pubspec.yaml` as a new dependency. |
| R10 | `flutter analyze` must report zero new warnings after the change. |

---

## Out of Scope

- Navigation or routing changes.
- Any layout change other than adding the missing email item.
- Localization: the app is pinned to English (`locale: const Locale('en')`);
  no changes needed.
- The "Hike" app name heading: it remains present and unchanged.
- Any change to `SplashScreen` or `AboutScreen`.

---

## Architecture Impact

The change is confined to a single widget file. No new layers, no new services,
no new state management.

```
AboutScreen / SplashScreen
  └─ AboutContent              ← ONLY FILE CHANGED
       └─ url_launcher (new dep) for GestureDetector / launchUrl
```

The dependency direction (UI widget → platform URL launch) is conventional and
does not violate the existing architecture.

---

## File Inventory

### Modified files (1)

| File | Change |
|------|--------|
| `lib/widgets/about_content.dart` | Add tappable GitHub URL and contact email; fix subtitle text; add `url_launcher` import. |

### Configuration changes (1)

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `url_launcher: ^6.3.0` (or latest stable) under `dependencies`. |

### New files

None.

### Files explicitly NOT changed

| File | Reason |
|------|--------|
| `lib/screens/splash_screen.dart` | Already uses `AboutContent`; no changes needed. |
| `lib/screens/about_screen.dart` | Already uses `AboutContent`; no changes needed. |
| `lib/main.dart` | No structural changes. |

---

## Implementation

### Step 1 — Add `url_launcher` to `pubspec.yaml`

```yaml
dependencies:
  # ... existing deps ...
  url_launcher: ^6.3.0
```

Run `flutter pub get` after editing.

### Step 2 — Update `lib/widgets/about_content.dart`

**Imports to add:**

```dart
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
```

**Updated `_buildInfoBlock()`:**

Replace the existing `Column` children to add the email entry and make the
GitHub URL tappable. The structure becomes:

```
Column(mainAxisSize: MainAxisSize.min)
  ClipRRect → Image.asset('assets/images/app_icon.png', 160×160)
  SizedBox(24)
  Text("Hike", white, bold, 36)
  SizedBox(8)
  Text("Essential tools for hiking.", white70, 16)
  SizedBox(32)
  RichText → tappable "github.com/david12345/hike/issues" (lightBlueAccent, underline)
  SizedBox(8)
  Text(version, white54, 12)
  SizedBox(4)
  RichText → tappable "david.a.ferreira@protonmail.com" (lightBlueAccent, underline)
```

Use a private helper `_launchUrl(String url)`:

```dart
Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

The GitHub URL tap calls `_launchUrl('https://github.com/david12345/hike/issues')`.
The email tap calls `_launchUrl('mailto:david.a.ferreira@protonmail.com')`.

Both use `TapGestureRecognizer` inside a `RichText` / `TextSpan`, which is the
idiomatic Flutter pattern for inline tappable text.

**`build` method is unchanged** — it remains:

```dart
@override
Widget build(BuildContext context) {
  return Center(child: _buildInfoBlock());
}
```

### Step 3 — Android intent filter (if needed)

`url_launcher` on Android requires no additional `AndroidManifest.xml` entries
for `https://` URLs (handled by the OS). For `mailto:` intents the OS routes to
installed email clients automatically. No manifest changes are needed.

---

## Spacing Reference

| Gap | SizedBox height |
|-----|----------------|
| After icon | 24 |
| After app name | 8 |
| After subtitle | 32 |
| After GitHub URL | 8 |
| After version | 4 |

These values match the existing spacing in `_buildInfoBlock()` for all items
that are already present; the only new gap is the `SizedBox(4)` between the
version number and the email (a tighter spacing because both are secondary
metadata).

---

## Dependencies

| Package | Action | Version | Purpose |
|---------|--------|---------|---------|
| `url_launcher` | ADD | ^6.3.0 | Open URLs and `mailto:` links from the info block |

All other dependencies are unchanged.

---

## Non-Functional Requirements

- **NF1 — No additional permissions.** `url_launcher` for `https://` and
  `mailto:` requires no new `AndroidManifest.xml` permissions beyond the
  existing `INTERNET` permission already declared.
- **NF2 — No Hive schema changes.** `build_runner` regeneration is not needed.
- **NF3 — No app icon changes.** `flutter_launcher_icons` regeneration is not
  needed.
- **NF4 — Battery neutral.** The change is UI-only; it has zero impact on the
  GPS pipeline, sensor streams, or background services.

---

## Testing Checklist

- [ ] Splash screen: info block is visually centered on a device with a tall
      status bar (e.g. Pixel 8).
- [ ] Splash screen: subtitle reads "Essential tools for hiking." (full stop,
      "tools" not "features").
- [ ] Splash screen: GitHub URL appears in lightBlueAccent with underline.
- [ ] Splash screen: tapping the GitHub URL opens
      `https://github.com/david12345/hike/issues` in the browser.
- [ ] Splash screen: email appears below the version number in lightBlueAccent
      with underline.
- [ ] Splash screen: tapping the email opens a mail compose intent addressed
      to `david.a.ferreira@protonmail.com`.
- [ ] About tab: all of the above checks pass identically (same widget).
- [ ] About tab: tap-to-navigate-to-Track still works (GestureDetector in
      `AboutScreen` is not broken by the new `TapGestureRecognizer`s — note
      that `RichText` taps are handled by the recognizer and do NOT propagate
      to the parent `GestureDetector`, so the user must tap a blank area to
      navigate back).
- [ ] No crash when no browser is installed (graceful no-op from `canLaunchUrl`
      guard).
- [ ] No crash when no email client is installed (same guard).
- [ ] `flutter analyze` reports zero new warnings.

---

## Documentation Updates

After implementation, update `CLAUDE.md`:

1. Bump `Version` field in the Project Overview table.
2. Add a row to the Release History table:
   `| v1.31.0 | Splash & About: tappable GitHub issues URL + contact email; fix subtitle text |`
3. Add `url_launcher` to the Key Dependencies table.
4. Add `splash-about-info-block.md` to the Feature Specs table.
5. Update the `AboutContent` doc comment in the Architecture tree if it
   describes the widget's content items.
