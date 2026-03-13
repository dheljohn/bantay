// import 'package:bantay/provider/map_initializer.dart';
// import 'package:bantay/services/tile_cache_service.dart';
// import 'package:bantay/widget/no_internet_button.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:developer';

// class MapScreen extends StatefulWidget {
//   const MapScreen({super.key});

//   @override
//   State<MapScreen> createState() => _MapScreenState();
// }

// class _MapScreenState extends State<MapScreen> {
//   final MapController _mapController = MapController();

//   bool _isLocating = false;

//   Future<void> _goToMyLocation() async {
//     setState(() => _isLocating = true);
//     log("📍 Refiring location check...");
//     try {
//       await MapInitializer.instance.refresh();
//       final position = MapInitializer.instance.userPosition;
//       if (position != null) {
//         _mapController.move(position, 16);
//         log("✅ Moved to: $position");
//       } else {
//         log("⚠️ No position available");
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Could not get location')),
//           );
//         }
//       }
//     } catch (e) {
//       log("❌ Location refire failed: $e");
//     } finally {
//       if (mounted) setState(() => _isLocating = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mapData = MapInitializer.instance;
//     final center = mapData.userPosition ?? const LatLng(14.5995, 120.9842);
//     final hasTiles = mapData.cachedTileCount > 0;

//     if (!mapData.hasInternet && !hasTiles) {
//       return Scaffold(
//         backgroundColor: Color.fromRGBO(10, 14, 25, 1),
//         body: NoInternetWidget(
//           onRetry: () async {
//             await MapInitializer.instance.refresh();
//             if (mounted) setState(() {});
//           },
//         ),
//       );
//     }

//     return Scaffold(
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: center,
//               initialZoom: 16,
//               minZoom: 5,
//               cameraConstraint: CameraConstraint.contain(
//                 bounds: LatLngBounds(LatLng(13.5, 119.5), LatLng(18.8, 122.4)),
//               ),
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: TileCacheService.tileUrl,
//                 userAgentPackageName: 'com.example.bantay',
//                 tileProvider:
//                     TileCacheService.isReady
//                         ? TileCacheService.getTileProvider() // cache-first (offline)
//                         : NetworkTileProvider(),

//                 // tileProvider: TileCacheService.getTileProvider(),
//                 errorTileCallback: (tile, error, stackTrace) {
//                   debugPrint('Tile error: $error');
//                 },
//                 tileBuilder: (context, tileWidget, tile) {
//                   return Container(
//                     color: Colors.white, // Background for the tile slot
//                     child: tileWidget,
//                   );
//                 },
//                 errorImage: const AssetImage('assets/images/errorImg.jpg'),
//               ),

//               CurrentLocationLayer(
//                 followOnLocationUpdate: FollowOnLocationUpdate.once,
//               ),
//               if (mapData.userPosition != null)
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       point: mapData.userPosition!,
//                       width: 40,
//                       height: 40,
//                       child: const Icon(
//                         Icons.my_location,
//                         color: Colors.blue,
//                         size: 30,
//                       ),
//                     ),
//                   ],
//                 ),
//               RichAttributionWidget(
//                 attributions: [
//                   TextSourceAttribution(
//                     '© OpenStreetMap contributors',
//                     onTap:
//                         () => launchUrl(
//                           Uri.parse('https://www.openstreetmap.org/copyright'),
//                         ),
//                   ),
//                 ],
//               ),
//             ],
//           ),

//           // Positioned(top: 40, right: 20, child: DownloadScreen()),
//           // My location FAB
//           Positioned(
//             bottom: 50,
//             right: 26,
//             child: FloatingActionButton(
//               onPressed: _isLocating ? null : _goToMyLocation,
//               backgroundColor: Colors.white,
//               child:
//                   _isLocating
//                       ? const SizedBox(
//                         width: 24,
//                         height: 24,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                       : const Icon(Icons.my_location, color: Colors.blue),
//             ),
//           ),
//           if (!mapData.hasInternet && TileCacheService.isReady && hasTiles)
//             Positioned(
//               bottom: 50,

//               left: 20,

//               child: Container(
//                 width: 80,

//                 // padding: const EdgeInsets.symmetric(
//                 //   vertical: 8,
//                 //   horizontal: 90,
//                 // ),
//                 decoration: BoxDecoration(
//                   color: Colors.black87,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: const Text(
//                   "White screen means no internet connection",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.white, fontSize: 12),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
