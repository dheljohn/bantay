import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'background_service.dart';

class ForegroundServiceManager {
  static bool _isStarting = false;
  static bool _isStopping = false;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bantay_monitoring',
        channelName: 'Bantay Monitoring',
        channelDescription: 'Keeps Bantay running to monitor your safe routes',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,

        // iconData: const NotificationIconData(
        //   resType: ResourceType.mipmap,
        //   resPrefix: ResourcePrefix.ic,
        //   name: 'launcher',
        // ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          15000,
        ), // every 5000 = 5 seconds
        autoRunOnBoot: true, // ✅ starts after device restart
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startService() async {
    if (_isStarting) return; // 🚫 prevent rapid double start
    _isStarting = true;

    try {
      final isRunning = await FlutterForegroundTask.isRunningService;

      if (!isRunning) {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Bantay Active',
          notificationText: 'Monitoring your safe routes',
          notificationButtons: [
            const NotificationButton(id: 'SAFE', text: "I'm Safe"),
            const NotificationButton(id: 'EMERGENCY', text: 'Emergency'),
          ],
          callback: startCallback,
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print("StartService error: $e");
    } finally {
      _isStarting = false;
    }
  }

  static Future<void> stopService() async {
    if (_isStopping) return; // 🚫 prevent rapid double stop
    _isStopping = true;

    try {
      final isRunning = await FlutterForegroundTask.isRunningService;

      if (isRunning) {
        await FlutterForegroundTask.stopService();
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print("StopService error: $e");
    } finally {
      _isStopping = false;
    }
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
