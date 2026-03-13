import 'dart:async';
import 'dart:math' as math;
import 'package:bantay/database/route_database.dart';
import 'package:bantay/provider/map_initializer.dart';
import 'package:bantay/services/location_service.dart';
import 'package:bantay/widget/no_internet_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_route.dart';
import '../services/tile_cache_service.dart';

class DrawRouteScreen extends StatefulWidget {
  const DrawRouteScreen({super.key});

  @override
  State<DrawRouteScreen> createState() => _DrawRouteScreenState();
}

class _DrawRouteScreenState extends State<DrawRouteScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _routeNameController = TextEditingController();

  List<LatLng> _routePoints = [];
  bool _isDrawing = false;
  bool _useTileCacheMaps = true;
  bool _isOverZoomed = false;
  final _tilesCacheReady = TileCacheService.isReady;

  // @override
  // Add point when user taps on map
  void _addPoint(LatLng point) {
    if (!_isDrawing) return;

    setState(() {
      _routePoints.add(point);
    });
  }

  // Remove last point
  void _undoLastPoint() {
    if (_routePoints.isEmpty) return;

    setState(() {
      _routePoints.removeLast();
    });
  }

  // Clear all points
  void _clearRoute() {
    setState(() {
      _routePoints.clear();
    });
  }

  // Calculate total distance
  double _calculateDistance() {
    if (_routePoints.length < 2) return 0;

    const distance = Distance();
    double total = 0;

    for (int i = 1; i < _routePoints.length; i++) {
      total += distance.as(
        LengthUnit.Meter,
        _routePoints[i - 1],
        _routePoints[i],
      );
    }

    return total / 1000; // Convert to km
  }

  // Start drawing mode
  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _routePoints.clear();
    });
  }

  // Show save dialog
  void _showSaveDialog() {
    if (_routePoints.length < 2) {
      _showError('Add at least 2 points to create a route');
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save Route'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _routeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Route Name',
                    hintText: 'e.g., Home to Work',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Points: ${_routePoints.length}'),
                      Text(
                        'Distance: ${_calculateDistance().toStringAsFixed(2)} km',
                      ),
                      Text(
                        'Created: ${DateTime.now().toString().split('.')[0]}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveRoute();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  // Save route to database
  Future<void> _saveRoute() async {
    final routeName = _routeNameController.text.trim();

    if (routeName.isEmpty) {
      _showError('Please enter a route name');
      return;
    }

    if (_routePoints.length < 2) {
      _showError('Route must have at least 2 points');
      return;
    }

    try {
      final route = SavedRoute(
        name: routeName,
        points: _routePoints,
        distance: _calculateDistance(),
        createdAt: DateTime.now(),
      );

      await RouteDatabase.instance.insertRoute(route);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true); // Return to previous screen
      }
    } catch (e) {
      _showError('Error saving route: $e');
    }
  }

  // Show error message
  void _showError(String message) {
    debugPrint('Error: $message');
  }

  @override
  Widget build(BuildContext context) {
    final mapData = MapInitializer.instance;
    final center = mapData.userPosition ?? const LatLng(14.5995, 120.9842);
    final hasTiles = mapData.cachedTileCount > 0;

    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 14, 25, 1),
      appBar: AppBar(
        toolbarHeight: 80.0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Draw Safe Route',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
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
        backgroundColor: Color.fromRGBO(10, 14, 25, 1),
        actions: [
          IconButton(
            icon: Icon(
              _useTileCacheMaps ? Icons.cloud_off : Icons.cloud,
              size: 25,
              color: Colors.white,
            ),

            onPressed:
                hasTiles
                    ? () {
                      setState(() => _useTileCacheMaps = !_useTileCacheMaps);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _useTileCacheMaps
                                ? 'Using offline maps'
                                : 'Using online maps',
                          ),
                        ),
                      );
                    }
                    : null,
            tooltip:
                _useTileCacheMaps ? 'Switch to online' : 'Switch to offline',
          ),
          if (_isDrawing && _routePoints.length >= 2)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _showSaveDialog,
              tooltip: 'Save Route',
              color: Colors.white,
            ),
        ],
      ),

      body: SafeArea(
        child:
            !mapData.hasInternet && !hasTiles
                ? SafeArea(
                  child: NoInternetWidget(
                    onRetry: () async {
                      await MapInitializer.instance.refresh();
                      if (mounted) setState(() {});
                    },
                  ),
                )
                : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 13.0,
                        maxZoom: 16,

                        onMapReady: () => _mapController.move(center, 13.0),
                        onPositionChanged: (position, hasGesture) {
                          final zoom = position.zoom;
                          final overZoom = zoom > 16.5;

                          if (overZoom != _isOverZoomed) {
                            setState(() => _isOverZoomed = overZoom);
                          }
                        },
                        onTap: (tapPosition, point) => _addPoint(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: TileCacheService.tileUrl,
                          userAgentPackageName: 'com.example.bantay',
                          tileProvider: TileCacheService.getTileProvider(),
                          // Add rate limiting
                          errorTileCallback: (tile, error, stackTrace) {
                            debugPrint('Tile error: $error');
                          },
                          tileBuilder: (context, tileWidget, tile) {
                            return Container(
                              color:
                                  Colors.white, // Background for the tile slot
                              child: tileWidget,
                            );
                          },
                          errorImage: const AssetImage(
                            'assets/images/errorImg.jpg',
                          ),
                        ),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              '© OpenStreetMap contributors',
                              onTap:
                                  () => launchUrl(
                                    Uri.parse(
                                      'https://www.openstreetmap.org/copyright',
                                    ),
                                  ),
                            ),
                          ],
                        ),

                        // Route corridor (wide, semi-transparent)
                        if (_routePoints.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 30.0,
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ],
                          ),

                        // Route path (main line)
                        if (_routePoints.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5.0,
                                color: Colors.green,
                              ),
                            ],
                          ),

                        // Route points markers
                        if (_routePoints.isNotEmpty)
                          MarkerLayer(
                            markers:
                                _routePoints.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final point = entry.value;

                                  Color markerColor =
                                      idx == 0
                                          ? Colors.green
                                          : idx == _routePoints.length - 1
                                          ? Colors.red
                                          : Colors.green.shade300;

                                  return Marker(
                                    point: point,
                                    width: 24,
                                    height: 24,
                                    child: GestureDetector(
                                      onLongPress: () {
                                        setState(() {
                                          _routePoints.removeAt(idx);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: markerColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            idx == 0
                                                ? 'S'
                                                : idx == _routePoints.length - 1
                                                ? 'E'
                                                : '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),

                        // User location marker
                        if (mapData.userPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: mapData.userPosition!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Add after the FlutterMap widget in your Stack
                    if (_isOverZoomed)
                      Positioned(
                        bottom: 120,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.zoom_out,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Cannot zoom in further',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Top info bar
                    if (_useTileCacheMaps)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _tilesCacheReady ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tilesCacheReady
                                    ? Icons.cloud_off
                                    : Icons.downloading,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _tilesCacheReady ? 'Offline' : 'Loading...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color:
                            _isDrawing
                                ? Colors.blue.shade100
                                : Colors.grey.shade200,
                        padding: const EdgeInsets.all(12),
                        child:
                            _isDrawing
                                ? Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Points: ${_routePoints.length}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Distance: ${_calculateDistance().toStringAsFixed(2)} km',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _routePoints.length < 2
                                          ? 'Tap on map to add points'
                                          : 'Tap ✓ to save route',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                )
                                : const Text(
                                  'Tap "Start Drawing" to begin',
                                  style: TextStyle(fontSize: 14),
                                ),
                      ),
                    ),

                    // Legend
                    Positioned(
                      top: 80,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(10, 14, 25, 1),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLegendItem(Colors.green, 'Start'),
                            _buildLegendItem(Colors.red, 'End'),
                            _buildLegendItem(Colors.green.shade300, 'Points'),
                            // _buildLegendItem(
                            //   Colors.green.withOpacity(0.3),
                            //   'Corridor',
                            // ),
                            _connectives(Colors.green, 'Path'),
                            _buildLegendItem(
                              const Color.fromARGB(255, 255, 255, 255),
                              'Area \nunavailable \noffline',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom controls
                    if (!_isDrawing)
                      Positioned(
                        bottom: 20,
                        left: 20,

                        child: ElevatedButton.icon(
                          onPressed: _startDrawing,
                          icon: const Icon(
                            Icons.edit_location,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Start Drawing Route',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(10, 14, 25, 1),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                          ),
                        ),
                      ),

                    if (_isDrawing)
                      Positioned(
                        bottom: 20,
                        left: 20,

                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,

                              child: ElevatedButton.icon(
                                onPressed:
                                    _routePoints.isEmpty
                                        ? null
                                        : _undoLastPoint,
                                icon: const Icon(Icons.undo),
                                label: const Text('Undo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 100,
                              child: ElevatedButton.icon(
                                onPressed: _clearRoute,
                                icon: const Icon(Icons.delete),
                                label: const Text('Clear'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Zoom controls
                    Positioned(
                      right: 10,
                      bottom: 100,
                      child: Column(
                        children: [
                          FloatingActionButton(
                            backgroundColor: Color.fromRGBO(10, 14, 25, 1),
                            mini: true,
                            heroTag: 'zoom_in',
                            onPressed: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                currentZoom + 1,
                              );
                            },
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            backgroundColor: Color.fromRGBO(10, 14, 25, 1),
                            mini: true,
                            heroTag: 'zoom_out',
                            onPressed: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                currentZoom - 1,
                              );
                            },
                            child: const Icon(
                              Icons.remove,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            backgroundColor: Color.fromRGBO(10, 14, 25, 1),
                            mini: true,
                            heroTag: 'my_location',
                            onPressed: () async {
                              var userPos =
                                  MapInitializer.instance.userPosition;

                              if (userPos == null) {
                                final pos =
                                    await LocationService().getLastPosition();
                                if (pos != null) {
                                  userPos = LatLng(pos.latitude, pos.longitude);
                                }
                              }

                              if (userPos != null) {
                                _mapController.move(userPos, 15.0);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to get your location',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _connectives(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          SizedBox(width: 5),
          Container(
            width: 7,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.rectangle),
          ),
          const SizedBox(width: 11),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
