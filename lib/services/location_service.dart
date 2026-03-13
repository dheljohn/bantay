// location_service.dart
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'dart:developer';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _controller = StreamController<Position>.broadcast();
  Stream<Position> get stream => _controller.stream;
  StreamSubscription<Position>? _subscription;

  // 👇 One-time fetch (from your _getUserLocation logic)
  Future<Position?> getLastPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // permission = await Geolocator.requestPermission();
        // if (permission == LocationPermission.denied)
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        log(" ❌ Awaiting permission");
        return null;
      }

      if (permission == LocationPermission.always) {
        return await Geolocator.getLastKnownPosition();
      }
      return null;
      // return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  // 👇 Continuous stream (your existing logic)
  void start() {
    _subscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _controller.add(position);
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
