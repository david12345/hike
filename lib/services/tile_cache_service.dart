// TODO(CR-3): dio_cache_interceptor_db_store is discontinued. The suggested
// replacement (dio_cache_interceptor_drift_store) does not exist on pub.dev.
// When flutter_map_cache ^2.0.0 is adopted, evaluate http_cache_drift_store
// (the officially listed replacement) or an alternative drift-based store.
// Until then, the current DbCacheStore remains functional.
import 'package:dio_cache_interceptor_db_store/dio_cache_interceptor_db_store.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:path_provider/path_provider.dart';

/// Manages a single shared disk-based tile cache for all flutter_map
/// [TileLayer] instances in the app.
///
/// Call [init] once during app startup (inside `SplashScreen`'s `Future.wait`).
/// Then pass [provider] to every `TileLayer`'s `tileProvider` parameter.
///
/// The cache stores tiles in the app's private cache directory using SQLite.
/// Tiles expire after 30 days. Android may evict this directory under
/// low-storage pressure.
class TileCacheService {
  static DbCacheStore? _store;
  static CachedTileProvider? _provider;

  /// Opens the SQLite-backed cache store.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  static Future<void> init() async {
    if (_store != null) return;
    final cacheDir = await getApplicationCacheDirectory();
    _store = DbCacheStore(
      databasePath: cacheDir.path,
      databaseName: 'tile_cache',
      logStatements: false,
    );
    // Stopgap size cap: evict stale (expired) entries on startup to prevent
    // unbounded disk growth. A count-based cap requires a custom DAO query
    // not available in this version of DbCacheStore (tile-cache-size-limit.md).
    await _store!.clean(staleOnly: true);
  }

  /// Returns a [CachedTileProvider] backed by the shared store, or a plain
  /// [NetworkTileProvider] if [init] has not completed yet.
  ///
  /// The [CachedTileProvider] instance is cached so that repeated calls
  /// return the same object, avoiding unnecessary allocations on every
  /// map rebuild.
  static TileProvider provider() {
    if (_store == null) return NetworkTileProvider();
    return _provider ??= CachedTileProvider(
      store: _store!,
      maxStale: const Duration(days: 30),
    );
  }

  /// Closes the underlying SQLite database. Call only on full app shutdown.
  static Future<void> dispose() async {
    _provider = null;
    await _store?.close();
  }
}
