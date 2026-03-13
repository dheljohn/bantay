import 'dart:convert';
import 'package:latlong2/latlong.dart';

class SavedRoute {
  final int? id;
  final String name;
  final List<LatLng> points;
  final double distance;
  final DateTime createdAt;
  final int timesUsed;

  SavedRoute({
    this.id,
    required this.name,
    required this.points,
    required this.distance,
    required this.createdAt,
    this.timesUsed = 0,
  });

  // Convert route to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'points': _pointsToJson(points),
      'distance': distance,
      'created_at': createdAt.toIso8601String(),
      'times_used': timesUsed,
    };
  }

  // Create route from database Map
  factory SavedRoute.fromMap(Map<String, dynamic> map) {
    return SavedRoute(
      id: map['id'] as int?,
      name: map['name'] as String,
      points: _jsonToPoints(map['points'] as String),
      distance: map['distance'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
      timesUsed: map['times_used'] as int? ?? 0,
    );
  }

  // Helper: Convert points list to JSON string
  static String _pointsToJson(List<LatLng> points) {
    final List<Map<String, double>> pointsList =
        points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
    return json.encode(pointsList);
  }

  // Helper: Convert JSON string to points list
  static List<LatLng> _jsonToPoints(String jsonStr) {
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded
        .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
        .toList();
  }

  // Create a copy with updated values
  SavedRoute copyWith({
    int? id,
    String? name,
    List<LatLng>? points,
    double? distance,
    DateTime? createdAt,
    int? timesUsed,
  }) {
    return SavedRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      points: points ?? this.points,
      distance: distance ?? this.distance,
      createdAt: createdAt ?? this.createdAt,
      timesUsed: timesUsed ?? this.timesUsed,
    );
  }
}
