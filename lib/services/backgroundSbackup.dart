// lib/services/background_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/route_database.dart';
import '../database/contacts_database.dart';
import 'route_detection_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BantayTaskHandler());
}

class BantayTaskHandler extends TaskHandler {
  final RouteDetectionService _routeDetection = RouteDetectionService();
  int _offRouteCount = 0;
  bool _emergencySent = false;

  static const int offRouteThreshold = 2;
  static const double routeTolerance = 100.0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('BantayTaskHandler started');
    _offRouteCount = 0;
    _emergencySent = false;
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('monitoring_enabled') ?? false;
    if (!isEnabled) return;
    await _checkLocation();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('BantayTaskHandler destroyed, timeout: $isTimeout');
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'stop') FlutterForegroundTask.stopService();
  }

  Future<void> _checkLocation() async {
    try {
      final routes = await RouteDatabase.instance.getAllRoutes();

      if (routes.isEmpty) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Bantay Active',
          notificationText: 'No routes set — add a safe route',
        );
        return;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Save last known location for UI to read
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);

      final current = LatLng(position.latitude, position.longitude);

      final (isOnRoute, matchedRoute, distance) = _routeDetection
          .checkIfOnAnyRoute(current, routes, tolerance: routeTolerance);

      if (isOnRoute) {
        // Back on route — reset everything
        _offRouteCount = 0;
        _emergencySent = false;
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Bantay Active ✓',
          notificationText: 'On safe route: ${matchedRoute?.name ?? ""}',
        );
      } else {
        _offRouteCount++;
        debugPrint('Off route count: $_offRouteCount/$offRouteThreshold');

        if (_offRouteCount >= offRouteThreshold && !_emergencySent) {
          // Trigger emergency
          await FlutterForegroundTask.updateService(
            notificationTitle: '⚠️ Bantay Alert',
            notificationText:
                'Off safe route! ${distance.toStringAsFixed(0)}m away',
          );
          await _triggerEmergency(position, distance);
          _emergencySent = true;
        } else if (_offRouteCount < offRouteThreshold) {
          await FlutterForegroundTask.updateService(
            notificationTitle: 'Bantay Warning',
            notificationText:
                'Possible deviation ($_offRouteCount/$offRouteThreshold)',
          );
        }
      }
    } catch (e) {
      debugPrint('Background check error: $e');
    }
  }

  Future<void> _triggerEmergency(Position position, double distance) async {
    try {
      final contacts = await ContactsDatabase.instance.getAllContacts();
      if (contacts.isEmpty) {
        debugPrint('No contacts to alert');
        return;
      }

      final lat = position.latitude;
      final lng = position.longitude;

      final message =
          '🚨 BANTAY ALERT: I may be in danger!\n'
          'I am off my safe route.\n'
          'My location: https://maps.google.com/?q=$lat,$lng\n'
          'Please check on me immediately.';

      for (final contact in contacts) {
        await _sendSMS(contact.phoneNumber, message);
      }

      debugPrint('Emergency triggered — alerted ${contacts.length} contacts');
    } catch (e) {
      debugPrint('Emergency trigger error: $e');
    }
  }

  Future<void> _sendSMS(String phoneNumber, String message) async {
    debugPrint('📱 SMS to $phoneNumber: $message');
  }
}

////
///backup on monitoring_service.dart new
///
// import 'dart:async';
// import 'dart:convert';

// import 'package:bantay/services/foreground_service_manager.dart';
// import 'package:flutter/foundation.dart';

// import 'package:shared_preferences/shared_preferences.dart';

// import '../models/monitoring_state.dart';

// class MonitoringService extends ChangeNotifier {
//   static final MonitoringService instance = MonitoringService._init();
//   MonitoringService._init();

//   MonitoringState _state = MonitoringState(
//     isEnabled: false,
//     status: MonitoringStatus.inactive,
//   );

//   MonitoringState get state => _state;

//   Future<void> initialize() async {
//     await _loadState();
//     // If was enabled before app closed, restart service
//     if (_state.isEnabled) {
//       await ForegroundServiceManager.startService();
//     }
//   }

//   Future<void> toggleMonitoring() async {
//     if (_state.isEnabled) {
//       await _stop();
//     } else {
//       await _start();
//     }
//   }

//   Future<void> _start() async {
//     _state = _state.copyWith(isEnabled: true, status: MonitoringStatus.active);
//     await _saveState();
//     await ForegroundServiceManager.startService();
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('monitoring_enabled', true);
//     notifyListeners();
//   }

//   Future<void> _stop() async {
//     _state = _state.copyWith(
//       isEnabled: false,
//       status: MonitoringStatus.inactive,
//     );
//     await _saveState();
//     await ForegroundServiceManager.stopService();
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('monitoring_enabled', false);
//     notifyListeners();
//   }

//   Future<void> _loadState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final stateJson = prefs.getString('monitoring_state');
//       if (stateJson != null) {
//         _state = MonitoringState.fromJson(json.decode(stateJson));
//       }
//     } catch (e) {
//       debugPrint('Error loading state: $e');
//     }
//   }

//   Future<void> _saveState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('monitoring_state', json.encode(_state.toJson()));
//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error saving state: $e');
//     }
//   }
// }
