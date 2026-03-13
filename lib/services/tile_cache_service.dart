import 'dart:async';
import 'dart:developer';
import 'package:bantay/provider/map_initializer.dart';
import 'package:bantay/services/internet_check.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class TileCacheService {
  static const String storeName = 'luzon_map';
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static bool isReady = false;
  // static bool _isInitializing = false; // 👈 add this
  // static Completer<void>? _initCompleter;
  static bool _backendInitialized = false; // 👈 add this

  static Future<bool> checkConnection() async {
    final isConnected = await InternetService.instance.hasInternet;
    return isConnected;
  }

  /// Initialize backend, store, and prefetch ~5MB of tiles
  static Future<void> init() async {
    if (isReady) return;

    try {
      if (!_backendInitialized) {
        log("🔄 Initializing FMTC backend...");
        await FMTCObjectBoxBackend().initialise();
        _backendInitialized = true;
        log("✅ FMTC backend initialized");
      } else {
        log("ℹ️ Backend already initialized, skipping");
      }

      final stores = await FMTCRoot.stats.storesAvailable;
      final storeExists = stores.any((s) => s.storeName == storeName);

      if (!storeExists) {
        log("🆕 Creating new store...");
        await FMTCStore(storeName).manage.create();
        log("✅ Store created");
      } else {
        log("ℹ️ Store exists, skipping creation");
      }

      isReady = true;
    } catch (e, st) {
      log("⚠️ FMTC init failed: $e\n$st");
      isReady = false;
    }
  }

  static Future<int> getCachedTileCount() async {
    try {
      final stats = await FMTCStore(storeName).stats.length;
      return stats;
    } catch (e) {
      return 0;
    }
  }

  /// Returns FlutterMap-ready TileProvider
  static TileProvider getTileProvider() {
    if (!isReady) {
      log('❌ TileCacheService not ready, using network fallback.');
      return NetworkTileProvider(
        headers: {
          'User-Agent': 'Bantay/1.0 (com.example.bantay)',
          'Referer': 'https://github.com/dheljohn',
        },
      ); // fallback
    }

    return FMTCStore(storeName).getTileProvider(
      headers: {
        'User-Agent': 'Bantay/1.0 (com.example.bantay)',
        'Referer': 'https://github.com/dheljohn',
      },
      settings: FMTCTileProviderSettings(
        behavior:
            MapInitializer.instance.hasInternet
                ? CacheBehavior.cacheFirst
                : CacheBehavior.cacheOnly, // offline-first
        // ⚠️ CRITICAL: This stops the provider from throwing
        // block-level exceptions when a tile is missing.
        errorHandler: (error) {
          log(
            "FMTC Error: ${error.message}",
          ); // Just log, don't return anything
        },
      ),
    );
  }

  /// Clear cache
  static Future<void> clearCache() async {
    try {
      await FMTCStore(storeName).manage.reset();
      isReady = false;
      log("🧹 Cache cleared.");
    } catch (e) {
      log("⚠️ Failed to clear cache: $e");
    }
  }

  /// Optional: Get cache size
  static Future<String> getCacheSize() async {
    try {
      final stats = await FMTCStore(storeName).stats.all;

      final mb = (stats.size / 1024).toStringAsFixed(2);

      return '$mb MB (${stats.length} tiles)';
    } catch (e) {
      return '0 MB (0 tiles)';
    }
  }
}
