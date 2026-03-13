import 'dart:async';
// import 'dart:io';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:bantay/database/route_database.dart';
import 'package:bantay/provider/map_initializer.dart';
import 'package:bantay/screens/dashboard.dart';
import 'package:bantay/services/foreground_service_manager.dart';
import 'package:bantay/services/tile_cache_service.dart';
import 'package:bantay/services/monitoring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_control/torch_control.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Launch the app UI immediately
  runApp(const BantayApp());

  // Initialize background services
  _backgroundInit();

  // Post-frame callback to initialize background services
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeServices());
  });
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'bantay_location_check') {
      // Read shared prefs to check if monitoring is enabled
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('monitoring_enabled') ?? false;
      if (!isEnabled) return true;

      // Send tick to foreground task handler
      FlutterForegroundTask.sendDataToTask('alarm_tick');
    }
    return true;
  });
}

// Separate function to keep main() clean
void _backgroundInit() {
  // We don't 'await' this so the app stays responsive
  unawaited(_doHeavyWork());
}

Future<void> _doHeavyWork() async {
  try {
    // A small delay (100ms) gives the UI a chance to finish its first build
    await Future.delayed(const Duration(milliseconds: 100));

    // Step 3: FMTC init
    log("🟡 FMTC init...");
    await TileCacheService.init();
    log("🟢 FMCT Done: ${TileCacheService.isReady}");

    log("🟡Initializing Map Provider...");
    await MapInitializer.init();
    log("🟢 Map Provider Initialized");

    // Initialize Camera/Torch - This was causing the long 'ignore id' logs
    if (Platform.isAndroid || Platform.isIOS) {
      await TorchControl.ready();
    }

    // Initialize Monitoring Service
    // await MonitoringService.instance.initialize();
    // log("🟢 Monitoring Service Initialized");

    // Initialize Notifications
    // await NotificationService.instance.initialize();

    log("🟡 Initializing Foreground Service...");
    ForegroundServiceManager.init();
    log("🟢 Foreground Service Initialized");

    // Load Database
    final routes = await RouteDatabase.instance.getAllRoutes();
    log("✅ System Ready. Routes: ${routes.length}");

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'bantay_check',
      'bantay_location_check',
      frequency: const Duration(minutes: 15), // minimum allowed by WorkManager
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
      ),
    );
  } catch (e) {
    log("❌ Init Error: $e");
  }
}

Future<void> _initializeServices() async {
  try {
    // 1️⃣ Load routes
    log("🔄 Loading routes...");
    final routes = await RouteDatabase.instance.getAllRoutes();
    log("✅ Routes loaded: ${routes.length}");

    // 2️⃣ Initialize notifications
    // print("🔄 Initializing notifications...");
    // await NotificationService.instance.initialize();
    log("✅ Notifications initialized");
  } catch (e, stack) {
    debugPrint('❌ Initialization error: $e');
    debugPrint(stack.toString());
  }
}

class BantayApp extends StatelessWidget {
  const BantayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MonitoringService.instance,
      child: MaterialApp(
        title: 'Bantay',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const Dashboard(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
