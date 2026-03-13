import 'dart:async';
import 'dart:convert';
import 'package:bantay/helpers/debug.dart';
import 'package:bantay/services/foreground_service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_sender_background/sms_sender.dart';
import '../models/monitoring_state.dart';

class MonitoringService extends ChangeNotifier {
  static final MonitoringService instance = MonitoringService._init();
  MonitoringService._init() {
    _loadStateOnStartup();
  }

  MonitoringState _state = MonitoringState(
    isEnabled: false,
    status: MonitoringStatus.inactive,
  );
  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  MonitoringState get state => _state;
  bool _isProcessing = true;
  bool get isProcessing => _isProcessing;

  bool _isReady = false;
  bool get isReady => _isReady;

  bool get isSwitchInteractable => _isReady && !_isProcessing;

  get timestamp => DateTime.now();

  Future<void> initialize() async {
    if (!_state.isEnabled) {
      await _start();
    }
  }

  Future<void> _loadStateOnStartup() async {
    _isReady = false;
    _isProcessing = true;
    notifyListeners();

    try {
      await _loadState();
      FlutterForegroundTask.initCommunicationPort();

      if (_state.isEnabled) {
        FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

        // ← only start if not already running, never stop a running service
        final isRunning = await FlutterForegroundTask.isRunningService;
        debugPrint('🔍 Service running on startup: $isRunning');
        if (!isRunning) {
          debugPrint('⚠️ Service was dead — restarting');
          await ForegroundServiceManager.startService();
        }
        notifyListeners();
      }
    } finally {
      LogHelper.info("✅ Monitoring _loadStateOnStartup() ${_state.toJson()}");
      _isReady = true;
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Future<void> _restartServiceOnly() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool('monitoring_enabled', true);

  //   final isRunning = await FlutterForegroundTask.isRunningService;
  //   if (!isRunning) {
  //     await ForegroundServiceManager.startService();
  //   }
  // }

  Future<bool> canStart() async {
    // 1️⃣ Check if GPS is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      LogHelper.info("❌ GPS is disabled");
      return false;
    }

    // 2️⃣ Check foreground location permission
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      LogHelper.info("❌ Foreground location not granted");
      return false;
    }

    // 3️⃣ Check background location permission (important for your app)
    final backgroundStatus = await Permission.locationAlways.status;
    if (!backgroundStatus.isGranted) {
      LogHelper.info("❌ Background location not granted");
      return false;
    }

    // 4️⃣ Optional: Check notification permission (Android 13+)
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      LogHelper.info("❌ Notification permission not granted");
      return false;
    }

    LogHelper.info("✅ Monitoring can start");
    return true;
  }

  Future<void> _enableMonitoring() async {
    Future<bool> requestPermission(Permission perm, String name) async {
      final status = await perm.request();
      if (status.isGranted) return true;

      if (status.isDenied) {
        debugPrint("$name denied");
        return false;
      }

      if (status.isPermanentlyDenied) {
        debugPrint("$name permanently denied, opening settings...");
        await openAppSettings();
        return false;
      }
      return false;
    }

    // 1️⃣ Foreground location

    bool fgGranted = await requestPermission(
      Permission.locationWhenInUse,
      "Foreground location",
    );
    if (!fgGranted) return;

    // 2️⃣ Background location

    bool bgGranted = await requestPermission(
      Permission.locationAlways,
      "Background location",
    );
    if (!bgGranted) return;

    await requestPermission(Permission.notification, "Notifications");
    await requestPermission(Permission.ignoreBatteryOptimizations, "Battery");
    await requestPermission(Permission.scheduleExactAlarm, "Exact Alarm");

    final smsSender = SmsSender();
    final smsGranted = await smsSender.requestSmsPermission();
    debugPrint('SMS permission: $smsGranted');

    final phoneGranted = await smsSender.requestPhoneStatePermission();
    debugPrint('Phone state permission: $phoneGranted');
  }

  Future<void> _startMonitoringService() async {
    if (await canStart()) {
      if (!_state.isEnabled) {
        await _start(); // only start if not already running
      }
    }
  }

  Future<void> startMonitoring() async {
    await _startMonitoringService(); //monitoring service
  }

  Future<void> startPermissions() async {
    await _enableMonitoring(); // permission
  }

  Future<List<String>> getMissingPermissions() async {
    List<String> missing = [];
    final smsSender = SmsSender();

    if (!await Permission.locationWhenInUse.isGranted) {
      missing.add("Foreground Location");
    }

    if (!await Permission.locationAlways.isGranted) {
      missing.add("Background Location");
    }

    if (!await Permission.notification.isGranted) {
      missing.add("Notifications");
    }

    // if (!await Permission.phone.isGranted) {
    //   missing.add("Phone");
    // }
    // if (!await Permission.sms.isGranted) {
    //   missing.add("SMS");
    // }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      missing.add("Battery");
    }
    if (!await Permission.scheduleExactAlarm.isGranted) {
      missing.add("Exact Alarm");
    }

    if (!await smsSender.checkPhoneStatePermission()) {
      missing.add("Phone State");
    }

    if (!await smsSender.checkSmsPermission()) {
      missing.add("SMS background");
    }

    return missing;
  }

  Future<void> checkPermissionsAndGuide(BuildContext context) async {
    final missing = await MonitoringService.instance.getMissingPermissions();

    if (missing.isNotEmpty) {
      // Ask for permissions first
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("Permissions Required"),
              content: Text(
                missing.last == "Foreground Location" ||
                        missing.last == "Background Location"
                    ? "Please enable location services in App Settings. \n\nSelect 'Always' to allow Bantay to access your location even when the app is not in use."
                    : "The app needs the following permissions:\n\n${missing.join("\n")}\n\nPlease enable them in App Settings.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await MonitoringService.instance.startPermissions();
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
      );
      return;
    }
    await MonitoringService.instance.startMonitoring();

    // Check empty routes and contacts
    // final routesEmpty = (await RouteDatabase.instance.getAllRoutes()).isEmpty;
    // final contactsEmpty =
    //     (await ContactsDatabase.instance.getAllContacts()).isEmpty;
  }

  void _onReceiveTaskData(Object data) {
    if (!_isReady) return;
    debugPrint("🔵 RAW data received from BG: ${data.runtimeType} = $data");
    // ✅ Skip non-JSON test messages
    if (data.toString() == 'test_ping') {
      debugPrint('🧪 Test ping received — communication working!');
      return;
    }
    try {
      final map = jsonDecode(data.toString()) as Map<String, dynamic>;
      debugPrint("🟢 Parsed map: $map");

      final status = MonitoringStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MonitoringStatus.active,
      );

      if (map['lat'] != null && map['lng'] != null) {
        final newLocation = LatLng(map['lat'] as double, map['lng'] as double);

        if (_currentLocation != newLocation) {
          _currentLocation = newLocation;
          notifyListeners();
        }
      }

      MonitoringState newState = _state;

      if (map.containsKey('status')) {
        final status = MonitoringStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => MonitoringStatus.active,
        );
        newState = newState.copyWith(status: status);
      }

      if (map.containsKey('offRouteCount')) {
        newState = newState.copyWith(
          offRouteConsecutiveCount: map['offRouteCount'],
        );
      }

      if (map.containsKey('updatesSent')) {
        newState = newState.copyWith(updatesSent: map['updatesSent']);
      }

      if (map.containsKey('remaining')) {
        newState = newState.copyWith(alertCountdownSeconds: map['remaining']);
      }

      if (map.containsKey('lastCheckTime')) {
        newState = newState.copyWith(
          lastCheckTime: DateTime.tryParse(map['lastCheckTime']),
        );
      }

      if (map.containsKey('offRouteSince')) {
        newState = newState.copyWith(
          offRouteSince: DateTime.tryParse(map['offRouteSince']),
        );
      }

      if (newState != _state) {
        _state = newState;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('🔴 Error receiving task data: $e');
    }
  }

  Future<void> toggleMonitoring() async {
    debugPrint("🔘 toggleMonitoring() called");

    if (_isProcessing) {
      debugPrint("⚠️ Toggle ignored: already processing");
      return;
    }

    _isProcessing = true;
    debugPrint("⏳ Processing started");
    notifyListeners(); // update UI immediately

    try {
      debugPrint("📊 Current state.isEnabled = ${_state.isEnabled}");

      if (_state.isEnabled) {
        debugPrint("🛑 Monitoring currently ENABLED → calling _stop()");
        await _stop();
        debugPrint("✅ _stop() completed");
      } else {
        debugPrint("🚀 Monitoring currently DISABLED → calling _start()");
        await _start();
        debugPrint("✅ _start() completed");
      }
    } catch (e, stack) {
      debugPrint("❌ Toggle error: $e");
      debugPrint("📍 Stacktrace: $stack");
    } finally {
      _isProcessing = false;
      debugPrint("✔ Processing finished");
      notifyListeners(); // re-enable button
    }
  }

  Future<void> _start() async {
    final stack = StackTrace.current;
    debugPrint("🔴 _start() called\n$stack");
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monitoring_enabled', true);

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      debugPrint("🚀 Starting foreground service");

      await ForegroundServiceManager.startService();
    }

    // ← read bg_status as source of truth before saving
    final bgStatus = prefs.getString('bg_status');
    final resolvedStatus =
        bgStatus != null
            ? MonitoringStatus.values.firstWhere(
              (e) => e.name == bgStatus,
              orElse: () => MonitoringStatus.active,
            )
            : MonitoringStatus.active;

    _state = _state.copyWith(isEnabled: true, status: resolvedStatus);

    await _saveState();
    notifyListeners(); // ← UI updates immediately with correct status

    debugPrint("✅ Monitoring _start() — ${DateTime.now()}");
  }

  Future<void> _stop() async {
    debugPrint("🛑 Stopping monitoring");

    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monitoring_enabled', false);

    final newState = _state.copyWith(
      isEnabled: false,
      status: MonitoringStatus.inactive,
      offRouteConsecutiveCount: 0,
      lastCheckTime: DateTime.now(),
      offRouteSince: null,
      updatesSent: 0,
      alertCountdownSeconds: null,
    );

    _state = newState;
    await _saveState();

    await ForegroundServiceManager.stopService();

    notifyListeners();

    debugPrint("✅ Monitoring stopped");
  }

  // Future<void> _loadState() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final stateJson = prefs.getString('monitoring_state');
  //     if (stateJson != null) {
  //       _state = MonitoringState.fromJson(json.decode(stateJson));
  //     }
  //     LogHelper.info("✅ Monitoring _loadState()");
  //   } catch (e) {
  //     debugPrint('Error loading state: $e');
  //   }
  // }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('monitoring_state');
      if (stateJson != null) {
        _state = MonitoringState.fromJson(json.decode(stateJson));
      }

      // ← only override if bg has ever saved a status
      final bgStatus = prefs.getString('bg_status');
      if (bgStatus != null && _state.isEnabled) {
        // ← only sync status if monitoring was actually enabled
        _state = _state.copyWith(
          status: MonitoringStatus.values.firstWhere(
            (e) => e.name == bgStatus,
            orElse: () => _state.status,
          ),
        );
      }

      LogHelper.info(
        "✅ _loadState() — status: ${_state.status}, isEnabled: ${_state.isEnabled}",
      );
    } catch (e) {
      debugPrint('Error loading state: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      LogHelper.success("✅ Monitoring _saveState(): ${_state.toJson()}");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('monitoring_state', json.encode(_state.toJson()));
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }
}
