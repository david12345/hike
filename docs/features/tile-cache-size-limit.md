# tile-cache-size-limit.md

## User Story

As a hiker who uses the app regularly over months, I want the tile cache to stay within a reasonable disk size, so that the app does not gradually fill up my device's storage without my knowledge.

## Background / Problem

Analysis report item **N5**.

`TileCacheService` initialises `DbCacheStore` with a 30-day TTL but no maximum size constraint. A user who hikes frequently and views many different regions will accumulate tiles indefinitely until they either expire after 30 days or the user manually clears app data. On a device with limited internal storage (32–64 GB, common on mid-range Android), an unbounded tile cache is a real risk — each tile is typically 10–50 KB; 10 000 tiles equals 100–500 MB.

## Requirements

1. Add a maximum size cap to the `DbCacheStore` initialisation in `TileCacheService`.
2. The cap must be configurable via a constant in `lib/utils/constants.dart` (e.g. `kTileCacheMaxSizeBytes = 500 * 1024 * 1024` for 500 MB).
3. The eviction strategy must preserve the most recently accessed tiles (LRU or TTL-first eviction — whichever `DbCacheStore` supports).
4. If `DbCacheStore` does not natively support a `maxSize` parameter, investigate and document the available workaround (e.g. periodic `store.clean()` with a size check, or the `dio_cache_interceptor_db_store` replacement tracked in `tile-cache-store-migration.md`).
5. Add a `debugPrint` log at startup showing the current cache size in MB so developers can monitor growth.

## Non-Goals

- Exposing a user-facing cache size setting or "clear cache" button (out of scope).
- Limiting the number of tiles per trail or per zoom level individually.
- Replacing `DbCacheStore` (tracked in `tile-cache-store-migration.md`).

## Design / Implementation Notes

**Files to touch:**
- `lib/utils/constants.dart` — add `kTileCacheMaxSizeBytes`.
- `lib/services/tile_cache_service.dart` — apply the cap to `DbCacheStore` init; add startup log.

**Research required:** check the `dio_cache_interceptor_db_driver` / `DbCacheStore` API for a `maxSize` or eviction parameter. If it does not exist natively, the workaround is a periodic `store.clean()` call that prunes entries beyond the size limit. Document the finding in this spec's implementation notes once researched.

**Constants sketch:**
```dart
/// Maximum tile cache disk size in bytes (500 MB).
const int kTileCacheMaxSizeBytes = 500 * 1024 * 1024;
```

## Acceptance Criteria

- [ ] `kTileCacheMaxSizeBytes` is defined in `constants.dart`.
- [ ] `TileCacheService` applies the size cap (or documents why it cannot be applied natively and implements the best available alternative).
- [ ] App startup logs the current tile cache size in MB.
- [ ] After filling the cache beyond the limit (simulated), older tiles are evicted rather than the app storing more than the cap.
- [ ] `flutter analyze` reports zero issues.
