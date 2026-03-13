import 'dart:async';
import 'dart:math' as math;
import 'package:bantay/database/contacts_database.dart';
import 'package:bantay/database/route_database.dart';
import 'package:bantay/helpers/status_color.dart';
import 'package:bantay/helpers/status_helper.dart';
import 'package:bantay/screens/dashboard.dart';
import 'package:bantay/widget/exclude.dart';
import 'package:bantay/widget/monitoring_switch.dart';
import 'package:bantay/widget/swipe_sound_button.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sms_sender_background/sms_sender.dart';
// import 'package:sms_sender/sms_sender.dart';
import '../services/monitoring_service.dart';
import 'package:bantay/widget/pulsing_circle_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _routeCount = 0;
  int _contactsCount = 0;
  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation; //
  bool featureEnabled = false; // keep the state in the page

  bool _sosPulsing = false; // ← add
  Timer? _sosTimer;

  final _smsSender = SmsSender();

  @override
  void initState() {
    super.initState();
    // Initialize monitoring service
    _setup();
  }

  void _toggleSOS() async {
    setState(() => _sosPulsing = !_sosPulsing);

    if (_sosPulsing) {
      // send immediately on press
      await _sendSOSSMS();
      // then keep sending every 30s
      _sosTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        await _sendSOSSMS();
      });
    } else {
      _sosTimer?.cancel();
      _sosTimer = null;
    }
  }

  // Future<void> _sendSOSSMS() async {
  //   final isRunning = await FlutterForegroundTask.isRunningService;
  //   if (!isRunning) {
  //     debugPrint('⚠️ SOS failed — foreground service not running');
  //     return;
  //   }
  //   FlutterForegroundTask.sendDataToTask('SOS');
  //   debugPrint('🆘 SOS command sent to background');
  // }

  Future<void> _sendSOSSMS() async {
    final status = await Permission.sms.status;
    debugPrint('📱 SMS permission: $status');
    debugPrint('🆘 SOS triggered');

    if (!status.isGranted) {
      debugPrint('⚠️ SOS failed — SMS permission not granted');
      return;
    }

    final contacts = await ContactsDatabase.instance.getAllContacts();
    if (contacts.isEmpty) {
      debugPrint('⚠️ No contacts to alert');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contacts added')),
      );
      return;
    }

    final location = MonitoringService.instance.currentLocation;

    final message =
        '🆘 SOS ALERT from Bantay!\n'
        'I need help immediately!\n'
        '${location != null ? 'My location: https://maps.google.com/?q=${location.latitude},${location.longitude}' : 'Location unavailable'}';

    for (final contact in contacts) {
      bool sent = false;

      for (int simSlot = 1; simSlot <= 2; simSlot++) {
        try {
          debugPrint(
            '📤 Sending to ${contact.phoneNumber} via SIM $simSlot...',
          );

          final bool success = await _smsSender
              .sendSms(
                phoneNumber: contact.phoneNumber,
                message: message,
                simSlot: simSlot,
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint(
                    '⚠️ SMS timeout to ${contact.phoneNumber} via SIM $simSlot',
                  );
                  return false;
                },
              );

          if (success) {
            debugPrint(
              '✅ SENT → ${contact.name} (${contact.phoneNumber}) via SIM $simSlot',
            );
            sent = true;
            break; // stop trying other SIMs
          }
        } catch (e) {
          debugPrint(
            '❌ FAILED [error] → ${contact.name} (${contact.phoneNumber}) via SIM $simSlot — $e',
          );
        }
      }

      if (!sent) {
        debugPrint(
          '🚨 FAILED BOTH SIMS → ${contact.name} (${contact.phoneNumber})',
        );
      }
    }
  }

  @override
  void dispose() {
    _sosTimer?.cancel(); // ← add
    super.dispose();
  }

  Future<void> _setup() async {
    _loadRouteCount();
    await _loadContactsCount();
  }

  Future<void> _loadRouteCount() async {
    final routes = await RouteDatabase.instance.getAllRoutes();
    if (mounted) setState(() => _routeCount = routes.length);
  }

  Future<void> _loadContactsCount() async {
    final contacts = await ContactsDatabase.instance.getAllContacts();
    if (mounted) setState(() => _contactsCount = contacts.length);
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

  Future<void> safePop(BuildContext context) async {
    if (Navigator.of(context).canPop() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> showEmptySafeRouteDialog(BuildContext parentContext) async {
    final dashboardState =
        parentContext.findAncestorStateOfType<DashboardState>();
    await showDialog(
      context: parentContext,
      builder:
          (_) => AlertDialog(
            title: const Text("No Safe Routes"),
            content: const Text("Please add at least one safe route."),
            actions: [
              TextButton(
                onPressed: () {
                  dashboardState?.onItemTapped(2); // safe
                  safePop(context);
                },
                child: const Text("Add Route"),
              ),
            ],
          ),
    );
  }

  Future<void> showEmptyContactDialog(BuildContext parentContext) async {
    final dashboardState =
        parentContext.findAncestorStateOfType<DashboardState>();

    await showDialog(
      context: parentContext,
      builder:
          (_) => AlertDialog(
            title: const Text("No Emergency Contact"),
            content: const Text("Please add at least one emergency contact."),
            actions: [
              TextButton(
                onPressed: () {
                  dashboardState?.onItemTapped(0);
                  if (Navigator.of(parentContext).canPop()) {
                    Navigator.of(parentContext).pop();
                  }
                },
                child: const Text("Add Contact"),
              ),
            ],
          ),
    );
  }

  // In HomeScreen — read it
  // Future<void> _loadLastLocation() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final lat = prefs.getDouble('last_lat');
  //   final lng = prefs.getDouble('last_lng');
  //   if (lat != null && lng != null && mounted) {
  //     setState(() => final location = service.currentLocation; = LatLng(lat, lng));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: MonitoringService.instance,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 80.0,

          title: TextButton(
            // onPressed: () => showSimplePopup(context),
            onPressed: () => Null,
            child: const Text(
              'Bantay',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
          ),

          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(22, 16, 26, 1),

                  Color.fromRGBO(10, 14, 25, 1),
                ],
                stops: [0.4, 0.6],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                transform: GradientRotation(math.pi / 2.385),
              ),
            ),
          ),
        ),
        backgroundColor: Color.fromRGBO(10, 14, 25, 1),
        body: dashB(),
      ),
    );
  }

  Consumer<MonitoringService> dashB() {
    return Consumer<MonitoringService>(
      builder: (context, service, child) {
        final state = service.state;
        // final location = service.currentLocation;

        // final location = service.currentLocation;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(30),
              child: AnimatedContainer(
                margin: const EdgeInsets.only(top: 20),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: double.infinity,
                height: 170,

                decoration: BoxDecoration(
                  // color: getStatusColor(state.status).withOpacity(0.2),
                  gradient: LinearGradient(
                    colors:
                        getStatusColor(state.status) ==
                                Color.fromRGBO(18, 26, 44, 1)
                            ? [
                              getStatusColor(state.status),
                              getStatusColor(state.status),
                            ]
                            : [
                              getStatusColor(state.status).withOpacity(.3),
                              getStatusColor(state.status).withOpacity(0.2),
                            ],
                    // stops: [0.4, 0.6],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  border: Border.all(
                    // color: getStatusColor(state.status),
                    color:
                        getStatusColor(state.status) ==
                                Color.fromRGBO(18, 26, 44, 1)
                            ? Color.fromRGBO(28, 34, 53, 1)
                            : getStatusColor(state.status).withAlpha(70),
                    width: 1,
                  ),

                  borderRadius: BorderRadius.circular(32),
                ),

                // color: getStatusColor(state.status).withOpacity(0.3),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Status",
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  getStatusText(state.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color.fromRGBO(136, 152, 177, 1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    getStatusColor(state.status) ==
                                            Color.fromRGBO(18, 26, 44, 1)
                                        ? Color.fromRGBO(31, 38, 54, 1)
                                        : getStatusColor(
                                          state.status,
                                        ).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(15),

                                // border: Border.all(
                                //   color: getStatusColor(state.status),
                                //   width: 2,
                                // ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                state.isEnabled
                                    ? Icons.shield
                                    : Icons.shield_outlined,
                                size: 35,
                                color:
                                    !state.isEnabled
                                        ? Color.fromRGBO(136, 152, 177, 1)
                                        : getStatusColor(state.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 260,
                        height: 60,

                        decoration: BoxDecoration(
                          color: Color.fromRGBO(10, 17, 26, 0.9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color:
                                getStatusColor(state.status) ==
                                        Color.fromRGBO(18, 26, 44, 1)
                                    ? Color.fromRGBO(28, 34, 53, 1)
                                    : getStatusColor(
                                      state.status,
                                    ).withAlpha(70),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(width: 16),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color:
                                        state.isEnabled
                                            ? getStatusColor(state.status)
                                            : Color.fromRGBO(68, 84, 108, 1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 9),
                                Text(
                                  state.isEnabled ? "Active" : "Inactive",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // SizedBox(height: 4),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(width: 9),
                                service.isProcessing
                                    ? Transform.scale(
                                      scale: 0.6,

                                      child: const SizedBox(
                                        width: 24,
                                        height: 24,

                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                    : Transform.scale(
                                      scale: 0.7,
                                      child: MonitoringSwitch(
                                        // key: ValueKey(state.isEnabled),
                                      ),
                                    ),
                                SizedBox(width: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [SwipeSoundButton(), SizedBox(height: 32)],
                    ),
                  ),

                  // if (state.isEnabled)
                  //   Positioned(
                  //     bottom: 1,
                  //     left: -10,
                  //     child: SizedBox(
                  //       // height: 20,
                  //       // width: 50,
                  //       child: Card(
                  //         color: Colors.grey.shade100,
                  //         child: Padding(
                  //           padding: const EdgeInsets.all(16),
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               const Text(
                  //                 'Debug Info',
                  //                 style: TextStyle(
                  //                   fontSize: 8,
                  //                   fontWeight: FontWeight.bold,
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 8),
                  //               // Text(
                  //               //   'Off-route count: ${state.offRouteConsecutiveCount}',
                  //               // ),
                  //               Selector<MonitoringService, int>(
                  //                 selector:
                  //                     (_, service) =>
                  //                         service
                  //                             .state
                  //                             .offRouteConsecutiveCount,
                  //                 builder: (_, count, __) {
                  //                   return Text(
                  //                     'Off-route count: $count',
                  //                     style: const TextStyle(fontSize: 8),
                  //                   );
                  //                 },
                  //               ),
                  //               if (state.offRouteSince != null)
                  //                 Text(
                  //                   'Off-route since: ${_formatTime(state.offRouteSince!)}',
                  //                   style: const TextStyle(fontSize: 8),
                  //                 ),
                  //               Text(
                  //                 'Updates sent: ${state.updatesSent}',
                  //                 style: const TextStyle(fontSize: 8),
                  //               ),
                  //               Text(
                  //                 '$_routeCount routes configured',
                  //                 style: TextStyle(
                  //                   color: Colors.grey.shade600,
                  //                   fontSize: 8,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // if (location != null)
                  //   Positioned(
                  //     top: 0,
                  //     child: Builder(
                  //       builder: (context) {
                  //         final loc = location; //! location!👈 unwrap once
                  //         return Card(
                  //           color: const Color.fromARGB(255, 253, 253, 253),
                  //           child: Padding(
                  //             padding: const EdgeInsets.all(12),
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.start,
                  //               children: [
                  //                 Text(
                  //                   'Lat: ${loc.latitude.toStringAsFixed(6)}',
                  //                 ),
                  //                 Text(
                  //                   'Lng: ${loc.longitude.toStringAsFixed(6)}',
                  //                 ),
                  //               ],
                  //             ),
                  //           ),
                  //         );
                  //       },
                  //     ),
                  //   ),
                  Positioned(
                    top: 60,
                    // bottom: 200,
                    right: 1,
                    left: 1,
                    child: PulsingCircleButton(
                      key: ValueKey(_sosPulsing),
                      icon: Icons.warning_amber_rounded,
                      label: 'SOS',
                      isPulsing: _sosPulsing,
                      onTap: _toggleSOS,
                      centerColor: const Color.fromRGBO(
                        239,
                        68,
                        68,
                        1,
                      ), // 👈 brighter = center
                      outerColor: const Color.fromRGBO(
                        100,
                        5,
                        5,
                        1,
                      ), // 👈 darker = edge
                      pulseColor: const Color.fromRGBO(
                        220,
                        20,
                        20,
                        1,
                      ), // 👈 glow color
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // String _formatTime(DateTime time) {
  //   final now = DateTime.now();
  //   final diff = now.difference(time);

  //   if (diff.inSeconds < 60) {
  //     return '${diff.inSeconds}s ago';
  //   } else if (diff.inMinutes < 60) {
  //     return '${diff.inMinutes}m ago';
  //   } else {
  //     return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  //   }
  // }
}
