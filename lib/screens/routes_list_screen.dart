import 'dart:math' as math;

import 'package:bantay/services/tile_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/saved_route.dart';
import '../database/route_database.dart';
import 'draw_route_screen.dart';

class RoutesListScreen extends StatefulWidget {
  const RoutesListScreen({Key? key}) : super(key: key);

  @override
  State<RoutesListScreen> createState() => _RoutesListScreenState();
}

class _RoutesListScreenState extends State<RoutesListScreen> {
  List<SavedRoute> _routes = [];
  bool _isLoading = true;
  double avgSpeedKmph = 4.8;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);

    try {
      final routes = await RouteDatabase.instance.getAllRoutes();
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading routes: $e');
    }
  }

  Future<void> _deleteRoute(int id) async {
    try {
      await RouteDatabase.instance.deleteRoute(id);
      await _loadRoutes();
      _showSuccess('Route deleted');
    } catch (e) {
      _showError('Error deleting route: $e');
    }
  }

  void _showDeleteConfirmation(SavedRoute route) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Route'),
            content: Text('Are you sure you want to delete "${route.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // ← add async
                  Navigator.pop(context);
                  await _deleteRoute(route.id!); // ← await
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(18, 26, 44, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Map Legend",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              _circleLegend(Colors.green, "Start"),
              _verticalLegend(Colors.green, "Route"),
              _circleLegend(Colors.red, "End"),
              _boxLegend(Colors.white, "Unavailable / Offline"),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _circleLegend(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            // color: color,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              // border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxLegend(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalLegend(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 4, height: 12, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(10, 14, 25, 1),
      appBar: AppBar(
        toolbarHeight: 80.0,
        title: const Text(
          'Safe Routes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
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
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 20),
              const Text(
                "Saved Routes",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(93, 108, 134, 1),
                ),
              ),
              IconButton(
                onPressed: () => _showLegend(context),
                icon: const Icon(Icons.info_outline, color: Colors.white),
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.7,
                child: FloatingActionButton(
                  backgroundColor: const Color.fromRGBO(33, 20, 29, 1),
                  foregroundColor: Color.fromRGBO(229, 64, 64, 1),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DrawRouteScreen(),
                      ),
                    );

                    if (result == true) {
                      _loadRoutes();
                    }
                  },
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _routes.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.route,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No routes yet',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to draw your first safe route',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadRoutes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _routes.length,
                        itemBuilder: (context, index) {
                          final route = _routes[index];
                          return Column(
                            children: [
                              // 1. THE MAP CONTAINER (with the Legend)
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(32),
                                    topRight: Radius.circular(32),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(32),
                                    topRight: Radius.circular(32),
                                  ),
                                  child: Stack(
                                    children: [
                                      // YOUR MAP
                                      FlutterMap(
                                        options: MapOptions(
                                          initialCameraFit:
                                              route.distance < 1
                                                  ? CameraFit.coordinates(
                                                    coordinates: route.points,
                                                    minZoom: 14,
                                                    maxZoom: 14,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          30.0,
                                                        ),
                                                  )
                                                  : CameraFit.bounds(
                                                    bounds:
                                                        LatLngBounds.fromPoints(
                                                          route.points,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          30.0,
                                                        ),
                                                  ),
                                          interactionOptions:
                                              const InteractionOptions(
                                                flags: InteractiveFlag.none,
                                              ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                TileCacheService.tileUrl,
                                            tileProvider:
                                                TileCacheService.getTileProvider(),
                                          ),
                                          PolylineLayer(
                                            polylines: [
                                              Polyline(
                                                points: route.points,
                                                strokeWidth: 4,
                                                color: Colors.green,
                                              ),
                                            ],
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: route.points.first,
                                                width:
                                                    route.distance < 1
                                                        ? 15
                                                        : 30,
                                                height:
                                                    route.distance < 1
                                                        ? 15
                                                        : 30,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width:
                                                          route.distance < 1
                                                              ? 1
                                                              : 2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'S',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            route.distance < 1
                                                                ? 10
                                                                : 15,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Marker(
                                                point: route.points.last,
                                                width:
                                                    route.distance < 1
                                                        ? 15
                                                        : 30,
                                                height:
                                                    route.distance < 1
                                                        ? 15
                                                        : 30,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width:
                                                          route.distance < 1
                                                              ? 1
                                                              : 2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'E',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            route.distance < 1
                                                                ? 10
                                                                : 15,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              //  THE INFO CARD (Details below map)
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(32),
                                  bottomRight: Radius.circular(32),
                                ),

                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(18, 26, 44, 1),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: const Color.fromRGBO(
                                          28,
                                          37,
                                          53,
                                          1,
                                        ),
                                        width: 1,
                                      ),
                                      left: BorderSide(
                                        color: const Color.fromRGBO(
                                          28,
                                          37,
                                          53,
                                          1,
                                        ),
                                        width: 1,
                                      ),
                                      right: BorderSide(
                                        color: const Color.fromRGBO(
                                          28,
                                          37,
                                          53,
                                          1,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(32),
                                      bottomRight: Radius.circular(32),
                                    ),
                                  ),
                                  // color: const Color.fromRGBO(18, 26, 44, 1),
                                  child: Column(
                                    // title: Text(
                                    //   route.name,
                                    //   style: const TextStyle(
                                    //     fontWeight: FontWeight.bold,
                                    //   ),
                                    // ),
                                    // subtitle: Text(
                                    //   '${route.distance.toStringAsFixed(2)} km',
                                    // ),
                                    // trailing: const Icon(Icons.chevron_right),
                                    children: [
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const SizedBox(width: 25),
                                          Text(
                                            route.name[0].toUpperCase() +
                                                route.name.substring(1),

                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 20,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            onPressed:
                                                () => _showDeleteConfirmation(
                                                  route,
                                                ),
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                        ],
                                      ),
                                      SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // const SizedBox(width: 20),
                                          Container(
                                            width: 135,
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: Color(0xFF0A111A),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),

                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.near_me_outlined,
                                                  size: 20,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${route.distance.toStringAsFixed(2)} km',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            width: 135,
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: Color(0xFF0A111A),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),

                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.access_time_outlined,
                                                  size: 20,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${((route.distance / avgSpeedKmph) * 60).round()} min walk',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                            ],
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailSheet extends StatefulWidget {
  final SavedRoute route;
  final VoidCallback onDelete;

  const _RouteDetailSheet({required this.route, required this.onDelete});

  @override
  State<_RouteDetailSheet> createState() => _RouteDetailSheetState();
}

class _RouteDetailSheetState extends State<_RouteDetailSheet> {
  bool _isOverZoomed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            widget.route.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                _infoRow(
                  'Distance',
                  '${widget.route.distance.toStringAsFixed(2)} km',
                ),
                _infoRow('Points', '${widget.route.points.length}'),
                _infoRow('Times Used', '${widget.route.timesUsed}'),
                _infoRow(
                  'Created',
                  DateFormat('MMM dd, yyyy').format(widget.route.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Route Preview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: widget.route.points.first,
                      initialZoom: 13.0,
                      maxZoom: 15.0,
                      // onPositionChanged: (position, hasGesture) {
                      //   setState(() => _isOverZoomed = position.zoom > 16.5);
                      // },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: TileCacheService.tileUrl,
                        userAgentPackageName: 'com.example.bantay',
                        tileProvider: TileCacheService.getTileProvider(),
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: widget.route.points,
                            strokeWidth: 30.0,
                            color: Colors.green.withOpacity(0.3),
                          ),
                          Polyline(
                            points: widget.route.points,
                            strokeWidth: 5.0,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.route.points.first,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: widget.route.points.last,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'E',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ✅ Rebuilds correctly now
                  if (_isOverZoomed)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_out,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'You have zoomed in too much!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Use Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
