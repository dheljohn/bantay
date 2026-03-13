import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();

  NotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _actionController =
      StreamController<String>.broadcast();

  Stream<String> get notificationStream => _actionController.stream;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // void _onNotificationTapped(NotificationResponse response) {
  //   switch (response.actionId) {
  //     case 'SAFE_CONFIRMAITON_ACTION':

  //       break;
  //     case 'DISMISS_ACTION':
  //       // Nothing needed, auto-cancel handled
  //       break;
  //     default:
  //       // Notification body tapped
  //       break;
  //   }
  // }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');

    if (response.actionId == null || response.actionId!.isEmpty) {
      _actionController.add("BODY_TAP");
    } else {
      _actionController.add(response.actionId!);
    }
  }

  Future<void> showMonitoringActive() async {
    const androidDetails = AndroidNotificationDetails(
      'monitoring_channel',
      'Monitoring',
      channelDescription: 'Auto-Protect monitoring status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    // const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      // iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '🛡️ Auto-Protect Active',
      'Monitoring your location every minute',
      details,
    );
  }

  Future<void> showOffRouteWarning(int count, int threshold) async {
    const androidDetails = AndroidNotificationDetails(
      'warning_channel',
      'Warnings',
      channelDescription: 'Off-route warnings',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    // const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      // iOS: iosDetails,
    );

    await _notifications.show(
      2,
      '⚠️ Off Route Warning',
      'You are off your safe routes ($count/$threshold checks)',
      details,
    );
  }

  Future<void> showOffRouteAlert(double distance) async {
    // Define Android notification with action buttons
    final androidDetails = AndroidNotificationDetails(
      'alert_channel', // channel id
      'Alerts', // channel name
      channelDescription: 'Emergency alerts',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: Colors.red,
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'SAFE_CONFIRMATION_ACTION', // actionId
          'I\'m safe!',
          showsUserInterface: true,
          // cancelNotification: true, // optional
        ),
        AndroidNotificationAction(
          'EMERGENCY_ACTION', // actionId
          'Emergency',
          showsUserInterface: true,
        ),
      ],
    );

    var details = NotificationDetails(android: androidDetails);

    // Show the notification
    await _notifications.show(
      3,
      '🚨 OFF SAFE ROUTE',
      'You are ${distance.toStringAsFixed(0)}m from any safe route. Alert will be sent soon.',
      details,
      payload: 'off_route_alert', // optional payload
    );
  }

  Future<void> showHeightenedMode(bool isEmergency, String message) async {
    const androidDetails = AndroidNotificationDetails(
      'heightened_channel',
      'Heightened Monitoring',
      channelDescription: 'Active monitoring with minute updates',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      color: Colors.orange,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      4,
      isEmergency ? '🚨 EMERGENCY MODE' : '🟡 MONITORING MODE',
      message,
      details,
    );
  }

  Future<void> showEmergencySMSSent() async {
    const androidDetails = AndroidNotificationDetails(
      'sms_channel',
      'SMS Alerts',
      channelDescription: 'SMS status notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      5,
      '📱 Emergency SMS Sent',
      'Your emergency contacts have been notified',
      details,
    );
  }

  Future<void> showLocationUpdate(int updateNumber) async {
    const androidDetails = AndroidNotificationDetails(
      'updates_channel',
      'Location Updates',
      channelDescription: 'Location update notifications',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      6,
      '📍 Location Update #$updateNumber',
      'Sent to emergency contacts',
      details,
    );
  }

  Future<void> showBackOnRoute(
    String routeName,
    Duration offRouteDuration,
    int updatesSent,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'alert_channel',
      'Alerts',
      channelDescription: 'Status alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.green,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final minutes = offRouteDuration.inMinutes;

    await _notifications.show(
      7,
      '✅ Back on Safe Route',
      'You returned to $routeName. Off-route: ${minutes}m. Updates sent: $updatesSent',
      details,
    );
  }

  Future<void> showError(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'error_channel',
      'Errors',
      channelDescription: 'Error notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.red,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(999, 'Error', message, details);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
