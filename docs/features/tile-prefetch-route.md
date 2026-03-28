# tile-prefetch-route.md

## User Story

As a hiker planning a route at home with a Wi-Fi connection, I want the app to automatically cache map tiles for the trail I am viewing, so that the map is available offline when I am on the trail without cell coverage.

## Background / Problem

Analysis report item **N1**.

The tile cache (`TileCacheService` / `flutter_map_cache`) is reactive: it only caches tiles that are actually rendered on screen. A hiker who browses a trail on the Trails screen or Trail Map screen will have tiles cached only for the zoom levels they manually navigated to. Tiles at closer zoom levels (12–16), which are the most useful for navigation on the trail, will not be cached unless the hiker manually zooms in to every part of the route. This defeats much of the offline-readiness value of the cache for users who plan ahead.

## Requirements

1. When a trail is loaded for display (on `TrailMapScreen` or the Trails preview panel), compute the bounding box of the trail's `LatLng` points.
2. Trigger a background tile pre-fetch for the computed bounding box at zoom levels 12, 13, 14, 15, and 16.
3. The pre-fetch must run in a background `Future` chain — it must not block the UI or delay trail rendering.
4. Use the same `CachedTileProvider` / `DbCacheStore` instance from `TileCacheService` so pre-fetched tiles are served by the normal tile provider.
5. Pre-fetch only the currently selected tile mode (OSM, Topo, or Satellite) to avoid tripling the download volume.
6. Show a brief progress indicator or snack bar informing the user that tiles are being cached (e.g. "Caching map tiles for offline use…").
7. Do not re-fetch tiles that are already in the cache (rely on the cache's existing TTL-based deduplication).
8. Limit the total pre-fetch tile count to a reasonable maximum (e.g. 500 tiles) to prevent excessive data usage on large trails. Log the actual count with `debugPrint`.

## Non-Goals

- Pre-fetching tiles for hike records in the Log screen.
- Pre-fetching at zoom levels above 16 (tile count grows exponentially).
- Providing a user toggle to disable pre-fetching (out of scope for now).
- Estimating or displaying the download size in MB.

## Design / Implementation Notes

**New utility function** (in `map_utils.dart` or a new `lib/utils/tile_prefetch.dart`):
```dart
Future<void> prefetchTilesForBounds(
  LatLngBounds bounds,
  String tileUrlTemplate,
  CacheStore cacheStore, {
  List<int> zoomLevels = const [12, 13, 14, 15, 16],
  int maxTiles = 500,
}) async { ... }
```

The tile URL for each `(z, x, y)` is constructed from `tileUrlTemplate` using standard slippy-map tile coordinates derived from `LatLngBounds` and zoom level.

**Files to touch:**
- `lib/utils/map_utils.dart` or new `lib/utils/tile_prefetch.dart`.
- `lib/screens/trail_map_screen.dart` — call pre-fetch after trail bounds are computed.
- `lib/screens/trails_screen.dart` — call pre-fetch when a trail preview is opened.

**Tile count guard:** for a given bounding box and zoom level, the number of tiles is `(x_max - x_min + 1) * (y_max - y_min + 1)`. Sum across all zoom levels; if the total exceeds `maxTiles`, skip the higher zoom levels first.

## Acceptance Criteria

- [ ] Opening a trail on `TrailMapScreen` triggers a background tile download for the trail's bounding box at zoom levels 12–16.
- [ ] The pre-fetch does not block or delay the map from rendering.
- [ ] `debugPrint` logs the number of tiles being pre-fetched.
- [ ] Pre-fetch respects the `maxTiles` cap (verified by testing with a very large trail bounding box).
- [ ] After pre-fetch completes, enabling airplane mode and opening the same trail shows cached tiles at zoom levels 12–16.
- [ ] `flutter analyze` reports zero issues.
