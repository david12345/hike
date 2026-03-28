# Hike

**Essential tools for hiking.**

![Version](https://img.shields.io/github/v/release/david12345/hike?label=version)

A free, open-source Android app for GPS trail recording, offline maps, and trail management.

[**Download APK →**](https://github.com/david12345/hike/releases/latest/download/hike.apk) · [Website](https://david12345.github.io/hike)

---

## Features

| Tab | Description |
|-----|-------------|
| **Track** | GPS recording with timer, distance, points, live compass, altitude, weather, and air pressure |
| **Map** | Live location and route polyline on OpenStreetMap. Tap a trail on the Trails screen to see it as a green guide line while recording |
| **Log** | List of all saved hikes. Tap to view the route on a full-screen map with stats panel |
| **Trails** | Import GPX/KML trails, preview on map, export, share. Tap the walk icon to start a guided hike |
| **About** | App info and version |

### Highlights
- Background GPS recording via Android foreground service
- Offline map tile caching (30-day SQLite cache)
- GPX and KML import/export
- OSM and OpenTopoMap tile toggle
- Crash recovery — checkpoint saves every 10 points or 30 seconds
- Compass with live heading degree
- Weather and air pressure via [Open-Meteo](https://open-meteo.com) (no API key)
- Step counter and calories
- No account required · No ads · No analytics

---

## Download

Grab the latest APK from the [Releases page](https://github.com/david12345/hike/releases).

Direct link: [`hike.apk`](https://github.com/david12345/hike/releases/latest/download/hike.apk)

> **Install:** Enable "Install from unknown sources" in Android Settings → Security, then open the downloaded APK.

---

## Screenshots

*Coming soon.*

---

## Build from source

**Requirements:** Flutter 3.41+, Android SDK 34, Java 17

```bash
git clone https://github.com/david12345/hike.git
cd hike

# Set local SDK paths
echo "sdk.dir=/path/to/android-sdk" > android/local.properties
echo "flutter.sdk=/path/to/flutter" >> android/local.properties

flutter pub get
flutter build apk --release
# APK: build/app/outputs/apk/release/hike.apk
```

---

## Android Auto — Development Setup

Hike supports Android Auto and displays a live OSM map, compass heading, and GPS coordinates on the car display.

### Sideloaded APK — required one-time setup

APKs installed outside the Play Store (via `adb install` or downloaded from GitHub Releases) are blocked from appearing in Android Auto by default. To allow sideloaded apps:

1. Open the **Android Auto** app on the phone.
2. Tap the **version string** in the top-right of the main screen **ten times** in rapid succession. A "Developer mode enabled" toast should appear.
3. Open the **three-dot overflow menu** (top-right) → tap **Developer settings**.
4. Scroll to find **"Unknown sources"** and toggle it **on**.
5. Disconnect and reconnect the USB cable (or restart Android Auto).
6. The Hike app should now appear in the Android Auto app launcher.

> **Note:** This step must be repeated after a factory reset or after reinstalling the Android Auto app.

### Usage

Connect the phone to a car head unit or the [Desktop Head Unit (DHU)](https://developer.android.com/training/cars/testing/dhu) emulator. Open Android Auto and tap the Hike icon to launch the navigation screen.

---

## Map data

Map tiles and data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), licensed under [ODbL](https://opendatacommons.org/licenses/odbl/).
Topographic tiles © [OpenTopoMap](https://opentopomap.org), [CC-BY-SA](https://creativecommons.org/licenses/by-sa/3.0/).

---

## Contributing / Issues

Found a bug or have a suggestion? [Open an issue](https://github.com/david12345/hike/issues).

---

## License

MIT
