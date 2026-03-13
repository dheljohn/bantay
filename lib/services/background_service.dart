import 'package:bantay/helpers/debug.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/route_database.dart';
import '../database/contacts_database.dart';
import '../models/monitoring_state.dart';
import 'route_detection_service.dart';
import 'dart:convert';
// import 'package:sms_sender/sms_sender.dart';
import 'package:sms_sender_background/sms_sender.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BantayTaskHandler());
}

class BantayTaskHandler extends TaskHandler {
  final RouteDetectionService _routeDetection = RouteDetectionService();

  // State
  MonitoringStatus _status = MonitoringStatus.active;
  int _offRouteCount = 0;
  int _updatesSent = 0;
  String? _offRouteSince;
  bool _waitingForResponse = false;
  DateTime? _alertSentAt;

  bool _justRestored = false;
  static var now = DateTime.now();

  static const int offRouteThreshold = 5;
  static const double routeTolerance = 100.0;
  static const int responseTimeoutSeconds = 30; // auto emergency if no response
  final _smsSender = SmsSender();
  bool _isProcessing = true;
  SharedPreferences? _prefs;

  // ─── Lifecycle ───────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🟠 BantayTaskHandler.onStart fired'); // ✅
    await _restoreState();
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // if (_isProcessing) return;
    // _isProcessing = true;
    try {
      debugPrint('🔁 onRepeatEvent fired at $timestamp'); // ✅ add this
      final isEnabled = _prefs?.getBool('monitoring_enabled') ?? false;
      debugPrint('🔁 monitoring_enabled = $isEnabled'); // ✅ add this
      if (!isEnabled) return;

      if (_justRestored) {
        _justRestored = false;
        _sendToUI({
          'status': _status.name,
          'offRouteCount': _offRouteCount,
          'updatesSent': _updatesSent,
          if (_offRouteSince != null) 'offRouteSince': _offRouteSince,
          'lastCheckTime': DateTime.now().toIso8601String(),
        });
        return;
      }

      // Check if waiting for user response and timed out
      if (_waitingForResponse && _alertSentAt != null) {
        final elapsed = DateTime.now().difference(_alertSentAt!).inSeconds;
        if (elapsed >= responseTimeoutSeconds) {
          debugPrint('No response from user — entering emergency mode');
          _waitingForResponse = false;
          await _enterEmergencyMode();
          return;
        }
        // Still waiting — don't do location check yet
        final remaining = responseTimeoutSeconds - elapsed;
        await _updateNotification(
          title: '⚠️ Are you safe?',
          text: 'Tap "I\'m Safe" or emergency starts in ${remaining}s',
          showButtons: true,
        );
        return;
      }

      await _checkLocation();
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _saveState();

    debugPrint('BantayTaskHandler destroyed');
  }

  // ─── Notification button actions ─────────────────────────────
  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('🔔 onNotificationButtonPressed: $id');
    switch (id) {
      case 'SAFE':
        _userConfirmedSafe();
        break;
      case 'EMERGENCY':
        _enterEmergencyMode();
        break;
      case 'STOP':
        FlutterForegroundTask.stopService();
        break;
    }
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('📨 onReceiveData called with: $data');
    final action = data.toString();
    debugPrint('*********Received action: $action');

    switch (action) {
      case 'alarm_tick':
        debugPrint('⏰ WorkManager tick — running check');
        _checkLocation();
        break;
      case 'SAFE':
        _userConfirmedSafe();
        break;
      case 'EMERGENCY':
        _enterEmergencyMode();
        break;
      case 'STOP':
        FlutterForegroundTask.stopService();
        break;
      // case 'SOS': // ← add this
      //   _sendManualSOS();
      //   break;
    }
  }

  // ─── Notification helper ──────────────────────────────────────
  static const _actionButtons = [
    NotificationButton(id: 'SAFE', text: "I'm Safe"),
    NotificationButton(id: 'EMERGENCY', text: 'Emergency'),
  ];

  Future<void> _updateNotification({
    required String title,
    required String text,
    bool showButtons = false,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationButtons: showButtons ? _actionButtons : [],
    );
  }

  // ─── Location check ──────────────────────────────────────────

  Future<void> _checkLocation() async {
    try {
      final routes = await RouteDatabase.instance.getAllRoutes();

      if (routes.isEmpty) {
        await _updateNotification(
          title: 'Bantay Active',
          text: 'No routes set — add a safe route',
          showButtons: true,
        );
        _sendToUI({'status': 'active', 'offRouteCount': 0});
        return;
      }

      // position fetch with proper fallback
      final position = await _getPosition();
      if (position == null) {
        debugPrint('⚠️ Could not get position — skipping check');
        return;
      }

      // Save location for UI
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);

      final current = LatLng(position.latitude, position.longitude);
      final (isOnRoute, matchedRoute, distance) = _routeDetection
          .checkIfOnAnyRoute(current, routes, tolerance: routeTolerance);

      switch (_status) {
        case MonitoringStatus.active:
          await _handleActiveState(isOnRoute, matchedRoute, distance, position);
          break;
        case MonitoringStatus.offRoute:
          if (!_waitingForResponse) {
            debugPrint('offRoute but not waiting — re-triggering alert');
            await _triggerOffRouteAlert(distance, position);
          }
          break;
        case MonitoringStatus.heightenedMonitoring:
        case MonitoringStatus.heightenedEmergency:
          await _handleHeightenedState(
            isOnRoute,
            matchedRoute,
            position,
            distance,
          );
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Background check error: $e');
    }
  }

  Future<Position?> _getPosition() async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();

      if (position == null ||
          DateTime.now().difference(position.timestamp).inMinutes > 2) {
        //2
        debugPrint(
          '📍 Getting fresh position... ${now.hour}: ${now.minute}.${now.second}',
        );

        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 1,
            ),
          ).timeout(
            const Duration(seconds: 9),
          ); // ← increase from 10s to 20s// try 5 to match onrepeat
        } catch (_) {
          // GPS timed out — fall back to last known even if stale
          debugPrint('⚠️ Fresh fix failed, using stale last known position');
          position = await Geolocator.getLastKnownPosition();
        }
      }

      if (position == null) return null;
      debugPrint('📍 Position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ getPosition failed: $e');
      return null;
    }
  }

  // ─── Active state ─────────────────────────────────────────────

  Future<void> _handleActiveState(
    bool isOnRoute,
    dynamic matchedRoute,
    double distance,
    Position position,
  ) async {
    if (isOnRoute) {
      _offRouteCount = 0;
      await _updateNotification(
        title: 'Bantay Active ✓',
        text: 'On safe route: ${matchedRoute?.name ?? ""}',
      );
      _sendToUI({
        'status': 'active',
        'offRouteCount': 0,
        'lat': position.latitude,
        'lng': position.longitude,
        'lastCheckTime': DateTime.now().toIso8601String(),
      });
    } else {
      _offRouteCount++;
      debugPrint('Off route count: $_offRouteCount/$offRouteThreshold');

      if (_offRouteCount >= offRouteThreshold) {
        await _triggerOffRouteAlert(distance, position);
      } else {
        await _updateNotification(
          title: 'Bantay Warning',
          text: 'Possible deviation ($_offRouteCount/$offRouteThreshold)',
          showButtons: true,
        );
        _sendToUI({
          'status': 'offRoute',
          'offRouteCount': _offRouteCount,
          'distance': distance,
          'lat': position.latitude,
          'lng': position.longitude,
          'lastCheckTime': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  // ─── Trigger alert ────────────────────────────────────────────

  Future<void> _triggerOffRouteAlert(double distance, Position position) async {
    debugPrint('ALERT: User off all safe routes!');

    _status = MonitoringStatus.offRoute;
    _offRouteSince = DateTime.now().toIso8601String();
    _waitingForResponse = true;
    _alertSentAt = DateTime.now();

    await _updateNotification(
      title: '⚠️ Off Safe Route!',
      text:
          'Tap "I\'m Safe" or emergency activates in ${responseTimeoutSeconds}s',
      showButtons: true,
    );

    _sendToUI({
      'status': 'offRoute',
      'offRouteCount': _offRouteCount,
      'distance': distance,
      'lat': position.latitude,
      'lng': position.longitude,
      'offRouteSince': _offRouteSince,
      'lastCheckTime': DateTime.now().toIso8601String(),
    });

    await _saveState();
  }

  // ─── User confirmed safe ──────────────────────────────────────

  Future<void> _userConfirmedSafe() async {
    debugPrint('User confirmed safe — heightened monitoring');

    _status = MonitoringStatus.heightenedMonitoring;
    _waitingForResponse = false;
    _offRouteCount = 0;

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Bantay — Enhanced Monitoring',
      notificationText: 'Monitoring closely — stay on your safe route',
    );

    _sendToUI({
      'status': 'heightenedMonitoring',
      'offRouteCount': 0,
      'lastCheckTime': DateTime.now().toIso8601String(),
    });

    await _saveState();
  }

  // ─── Emergency mode ───────────────────────────────────────────

  Future<void> _enterEmergencyMode() async {
    debugPrint('EMERGENCY MODE ACTIVATED');

    _status = MonitoringStatus.heightenedEmergency;
    _waitingForResponse = false;
    _updatesSent = 0;

    await _updateNotification(
      title: '🚨 EMERGENCY MODE',
      text: 'Sending location updates to contacts...',
      // showButtons: true,
    );

    _sendToUI({
      'status': 'heightenedEmergency',
      'offRouteCount': _offRouteCount,
      'offRouteSince': _offRouteSince,
      'lastCheckTime': DateTime.now().toIso8601String(),
    });

    // Send first SMS immediately
    await _sendEmergencySMS();
    await _saveState();
  }

  // ─── Heightened state ─────────────────────────────────────────

  Future<void> _handleHeightenedState(
    bool isOnRoute,
    dynamic matchedRoute,
    Position position,
    double distance,
  ) async {
    if (isOnRoute) {
      await _handleBackOnRoute(matchedRoute, position);
    } else {
      if (_status == MonitoringStatus.heightenedEmergency) {
        debugPrint('🚨 heightenedEmergency branch');
        _updatesSent++;
        await _sendLocationUpdate(position);
        await _updateNotification(
          title: '🚨 EMERGENCY — Update #$_updatesSent',
          text: 'Sending location to contacts...',
          showButtons: true,
        );
        _sendToUI({
          'status': 'heightenedEmergency',
          'updatesSent': _updatesSent,
          'offRouteSince': _offRouteSince,
          'lastCheckTime': DateTime.now().toIso8601String(),
        });
      } else if (_status == MonitoringStatus.heightenedMonitoring) {
        // ← re-trigger alert if still off route
        debugPrint('⚠️ heightenedMonitoring branch — count: $_offRouteCount');
        _offRouteCount++;

        if (_offRouteCount >= offRouteThreshold) {
          await _triggerOffRouteAlert(distance, position);
        } else {
          await _updateNotification(
            title: 'Bantay — Enhanced Monitoring',
            text:
                'Still off route — watching closely ($_offRouteCount/$offRouteThreshold)',
          );
          _sendToUI({
            'status': 'heightenedMonitoring',
            'offRouteCount': _offRouteCount,
            'distance': distance,
            'lat': position.latitude,
            'lng': position.longitude,
            'lastCheckTime': DateTime.now().toIso8601String(),
          });
        }
      }
    }
  }

  // ─── Back on route ────────────────────────────────────────────

  Future<void> _handleBackOnRoute(dynamic route, Position position) async {
    debugPrint('✅ Back on safe route: ${route?.name}');

    final prevStatus = _status;
    _status = MonitoringStatus.active;
    _offRouteCount = 0;
    _updatesSent = 0;
    _offRouteSince = null;
    _waitingForResponse = false;

    await _updateNotification(
      title: 'Bantay Active ✓',
      text: 'Back on safe route: ${route?.name ?? ""}',
    );

    _sendToUI({
      'status': 'active',
      'offRouteCount': 0,
      'updatesSent': 0,
      'lat': position.latitude,
      'lng': position.longitude,
      'lastCheckTime': DateTime.now().toIso8601String(),
      'backOnRoute': true,
      'routeName': route?.name ?? '',
      'wasEmergency': prevStatus == MonitoringStatus.heightenedEmergency,
    });

    await _saveState();
  }

  // ─── SMS ──────────────────────────────────────────────────────

  Future<void> _sendEmergencySMS() async {
    try {
      final contacts = await ContactsDatabase.instance.getAllContacts();
      if (contacts.isEmpty) {
        debugPrint('No contacts to alert');
        return;
      }

      final position = await Geolocator.getLastKnownPosition();
      final lat = position?.latitude ?? 0;
      final lng = position?.longitude ?? 0;

      final message =
          '🚨 BANTAY ALERT: I may be in danger!\n'
          'I am off my safe route.\n'
          'My location: https://maps.google.com/?q=$lat,$lng\n'
          'Please check on me immediately.';

      for (final contact in contacts) {
        await _sendSMS(contact.phoneNumber, message);
      }

      debugPrint('Emergency SMS sent to ${contacts.length} contacts');
    } catch (e) {
      debugPrint('SMS error: $e');
    }
  }

  Future<void> _sendLocationUpdate(Position position) async {
    try {
      final contacts = await ContactsDatabase.instance.getAllContacts();
      if (contacts.isEmpty) return;

      final message =
          '📍 BANTAY UPDATE #$_updatesSent\n'
          'Still off my safe route.\n'
          'Location: https://maps.google.com/?q=${position.latitude},${position.longitude}';

      for (final contact in contacts) {
        await _sendSMS(contact.phoneNumber, message);
      }
    } catch (e) {
      debugPrint('Location update error: $e');
    }
  }

  // ─── SMS ──────────────────────────────────────────────────────

  Future<void> _sendSMS(String phoneNumber, String message) async {
    try {
      LogHelper.info("Send SMS Fired");

      bool hasPermission = await _smsSender.checkSmsPermission();
      if (!hasPermission) {
        hasPermission = await _smsSender.requestSmsPermission();
        if (!hasPermission) {
          debugPrint('❌ SMS permission denied');
          return;
        }
      }

      // simSlot 0 = SIM 1, 1 = SIM 2
      final bool success = await _smsSender.sendSms(
        phoneNumber: phoneNumber,
        message: message,
        simSlot: 0,
      );

      if (success) {
        debugPrint('✅ SMS sent to $phoneNumber');
      } else {
        debugPrint('❌ SMS failed to $phoneNumber');
      }
    } catch (e) {
      debugPrint('❌ SMS error to $phoneNumber: $e');
    }
  }

  // Future<void> _sendSMS(String phoneNumber, String message) async {
  //   try {
  //     LogHelper.info("Send SMS Fired");

  //     final simCards = await SmsSender.getSimCards();
  //     final simSlot = simCards.isNotEmpty ? simCards[0]['simSlot'] : 0;
  //     final simName =
  //         simCards.isNotEmpty ? simCards[0]['displayName'] ?? 'SIM 1' : 'SIM 1';

  //     await SmsSender.sendSms(
  //       phoneNumber: phoneNumber,
  //       message: message,
  //       simSlot: simSlot,
  //     ).timeout(
  //       const Duration(seconds: 10),
  //       onTimeout: () {
  //         debugPrint('⚠️ SMS timeout to $phoneNumber via $simName');
  //         return 'timeout';
  //       },
  //     );

  //     debugPrint('📱 SMS sent to $phoneNumber via $simName');
  //   } catch (e) {
  //     debugPrint('❌ SMS failed to $phoneNumber: $e');
  //   }
  // }

  // Future<void> _sendManualSOS() async {
  //   debugPrint('🆘 Manual SOS triggered');

  //   final position = await Geolocator.getLastKnownPosition();
  //   final lat = position?.latitude ?? 0;
  //   final lng = position?.longitude ?? 0;

  //   final contacts = await ContactsDatabase.instance.getAllContacts();
  //   if (contacts.isEmpty) {
  //     debugPrint('No contacts to alert');
  //     return;
  //   }

  //   final message =
  //       '🆘 SOS ALERT from Bantay!\n'
  //       'I need help immediately!\n'
  //       'My location: https://maps.google.com/?q=$lat,$lng';

  //   for (final contact in contacts) {
  //     await _sendSMS(contact.phoneNumber, message);
  //   }
  // }
  // ─── Helpers ──────────────────────────────────────────────────

  // void _sendToUI(Map<String, dynamic> data) {
  //   final encoded = jsonEncode(data);
  //   debugPrint('🟡 Sending to UI: $encoded');
  //   FlutterForegroundTask.sendDataToMain(encoded);
  // }
  void _sendToUI(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    try {
      FlutterForegroundTask.sendDataToMain(encoded);
      debugPrint('🟡_sendToUI-- Sending to UI : $encoded');
    } catch (e) {
      debugPrint('⚠️ sendToUI failed (UI likely closed): $e');
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_status', _status.name);
    await prefs.setInt('bg_off_route_count', _offRouteCount);
    await prefs.setInt('bg_updates_sent', _updatesSent);
    await prefs.setBool('bg_waiting_response', _waitingForResponse);

    // ✅ Always write these — even if null (clear old values)
    await prefs.setString('bg_off_route_since', _offRouteSince ?? '');
    await prefs.setString(
      'bg_alert_sent_at',
      _alertSentAt?.toIso8601String() ?? '',
    );
  }

  // Future<void> _restoreState() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final statusName = prefs.getString('bg_status') ?? 'active';

  //   _status = MonitoringStatus.values.firstWhere(
  //     (e) => e.name == statusName,
  //     orElse: () => MonitoringStatus.active,
  //   );
  //   _offRouteCount = prefs.getInt('bg_off_route_count') ?? 0;
  //   _updatesSent = prefs.getInt('bg_updates_sent') ?? 0;
  //   _waitingForResponse = prefs.getBool('bg_waiting_response') ?? false;

  //   // ✅ Handle empty strings properly
  //   final alertSentAtStr = prefs.getString('bg_alert_sent_at');
  //   _alertSentAt =
  //       (alertSentAtStr != null && alertSentAtStr.isNotEmpty)
  //           ? DateTime.tryParse(alertSentAtStr)
  //           : null;

  //   final offRouteSince = prefs.getString('bg_off_route_since');
  //   _offRouteSince =
  //       (offRouteSince != null && offRouteSince.isNotEmpty)
  //           ? offRouteSince
  //           : null;

  //   debugPrint('Restored state: $_status, offRouteCount: $_offRouteCount');
  // }
  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final statusName = prefs.getString('bg_status') ?? 'active';

    _status = MonitoringStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => MonitoringStatus.active,
    );
    _offRouteCount = prefs.getInt('bg_off_route_count') ?? 0;
    _updatesSent = prefs.getInt('bg_updates_sent') ?? 0;
    _waitingForResponse = prefs.getBool('bg_waiting_response') ?? false;

    final alertSentAtStr = prefs.getString('bg_alert_sent_at');
    _alertSentAt =
        (alertSentAtStr != null && alertSentAtStr.isNotEmpty)
            ? DateTime.tryParse(alertSentAtStr)
            : null;

    final offRouteSince = prefs.getString('bg_off_route_since');
    _offRouteSince =
        (offRouteSince != null && offRouteSince.isNotEmpty)
            ? offRouteSince
            : null;

    // 1️⃣ already in emergency — clear waiting flags, no need to re-enter
    if (_status == MonitoringStatus.heightenedEmergency) {
      _waitingForResponse = false;
      _alertSentAt = null;
    }
    // 2️⃣ was waiting for response (offRoute) — check if timeout elapsed
    else if (_status == MonitoringStatus.offRoute &&
        _waitingForResponse &&
        _alertSentAt != null) {
      final elapsed = DateTime.now().difference(_alertSentAt!).inSeconds;
      if (elapsed >= responseTimeoutSeconds) {
        _waitingForResponse = false;
        await _enterEmergencyMode();
        return; // _enterEmergencyMode calls _sendToUI
      }
    }
    _justRestored = true;

    debugPrint(
      'INSIDE BSERVICE--Restored state: $_status, offRouteCount: $_offRouteCount',
    );

    // _sendToUI({
    //   'status': _status.name,
    //   'offRouteCount': _offRouteCount,
    //   'updatesSent': _updatesSent,
    //   if (_offRouteSince != null) 'offRouteSince': _offRouteSince,
    //   'lastCheckTime': DateTime.now().toIso8601String(),
    // });
  }
}
