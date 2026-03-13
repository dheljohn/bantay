import 'package:latlong2/latlong.dart';
import 'package:bantay/services/tile_cache_service.dart';
import 'package:bantay/services/location_service.dart';

class MapInitializer {
  static final MapInitializer instance = MapInitializer._();
  MapInitializer._();

  bool hasInternet = false;
  bool tileServiceReady = false;
  int cachedTileCount = 0;
  LatLng? userPosition;

  /// Called ONCE from main.dart — initializes FMTC backend
  static Future<void> init() async {
    // Step 1: Initialize FMTC (ObjectBox — runs only once)
    //done in main
    // await TileCacheService.init();

    instance.tileServiceReady = TileCacheService.isReady;

    // Step 2: Start live location stream
    LocationService().start();
    LocationService().stream.listen((position) {
      instance.userPosition = LatLng(position.latitude, position.longitude);
    });

    // Step 3: Run first refresh
    await instance.refresh();
  }

  /// Called anytime after init — rechecks connection, location, tile count
  Future<void> refresh() async {
    // Step 1: Check internet
    hasInternet = await TileCacheService.checkConnection();

    // Step 2: Last known location
    final pos = await LocationService().getLastPosition();
    if (pos != null) {
      userPosition = LatLng(pos.latitude, pos.longitude);
    }

    // Step 3: Cached tile count
    cachedTileCount = await TileCacheService.getCachedTileCount();

    // Step 4: Sync ready state
    tileServiceReady = TileCacheService.isReady;
  }
}
