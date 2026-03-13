import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';

class RouteDetectionService {
  // Distance calculator
  final Distance _distance = const Distance();

  // Default tolerance: 100 meters from route
  static const double defaultTolerance = 100.0; // meters

  /// Check if a point is on ANY of the provided routes
  /// Returns: (isOnRoute, matchedRoute, distanceFromRoute)
  (bool, SavedRoute?, double) checkIfOnAnyRoute(
    LatLng currentLocation,
    List<SavedRoute> routes, {
    double tolerance = defaultTolerance,
  }) {
    if (routes.isEmpty) {
      return (false, null, double.infinity);
    }

    SavedRoute? closestRoute;
    double minDistance = double.infinity;

    // Check each route
    for (final route in routes) {
      final distance = getDistanceFromRoute(currentLocation, route);

      if (distance < minDistance) {
        minDistance = distance;
        closestRoute = route;
      }
    }

    // User is "on route" if within tolerance
    final isOnRoute = minDistance <= tolerance;

    return (isOnRoute, closestRoute, minDistance);
  }

  /// Calculate minimum distance from current location to a route
  double getDistanceFromRoute(LatLng currentLocation, SavedRoute route) {
    if (route.points.isEmpty) return double.infinity;
    if (route.points.length == 1) {
      return _distance.as(
        LengthUnit.Meter,
        currentLocation,
        route.points.first,
      );
    }

    double minDistance = double.infinity;

    // Check distance to each point on the route
    for (final point in route.points) {
      final dist = _distance.as(LengthUnit.Meter, currentLocation, point);

      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    // Also check distance to line segments between points
    for (int i = 0; i < route.points.length - 1; i++) {
      final segmentDist = _distanceToLineSegment(
        currentLocation,
        route.points[i],
        route.points[i + 1],
      );

      if (segmentDist < minDistance) {
        minDistance = segmentDist;
      }
    }

    return minDistance;
  }

  /// Calculate perpendicular distance from point to line segment
  double _distanceToLineSegment(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    // If start and end are the same, just return distance to that point
    if (lineStart.latitude == lineEnd.latitude &&
        lineStart.longitude == lineEnd.longitude) {
      return _distance.as(LengthUnit.Meter, point, lineStart);
    }

    // Calculate distances
    final distToStart = _distance.as(LengthUnit.Meter, point, lineStart);
    final distToEnd = _distance.as(LengthUnit.Meter, point, lineEnd);
    final lineLength = _distance.as(LengthUnit.Meter, lineStart, lineEnd);

    // If very close to start or end, return that distance
    if (distToStart < 10) return distToStart;
    if (distToEnd < 10) return distToEnd;

    // Use simplified perpendicular distance
    // For more accuracy, you could use Haversine-based calculations
    // But this is sufficient for our use case

    // Calculate the parameter t for the projection
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      return distToStart;
    }

    final t =
        ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    // Clamp t to [0, 1] to stay on the segment
    final tClamped = t.clamp(0.0, 1.0);

    // Find the closest point on the line segment
    final closestLat = lineStart.latitude + tClamped * dy;
    final closestLng = lineStart.longitude + tClamped * dx;
    final closestPoint = LatLng(closestLat, closestLng);

    return _distance.as(LengthUnit.Meter, point, closestPoint);
  }

  /// Get human-readable direction from current location to nearest route point
  String getDirectionToRoute(LatLng currentLocation, SavedRoute route) {
    if (route.points.isEmpty) return 'Unknown';

    // Find closest point
    LatLng closestPoint = route.points.first;
    double minDistance = double.infinity;

    for (final point in route.points) {
      final dist = _distance.as(LengthUnit.Meter, currentLocation, point);
      if (dist < minDistance) {
        minDistance = dist;
        closestPoint = point;
      }
    }

    // Calculate bearing
    final bearing = _distance.bearing(currentLocation, closestPoint);

    return _bearingToDirection(bearing);
  }

  /// Convert bearing (0-360) to cardinal direction
  String _bearingToDirection(double bearing) {
    // Normalize bearing to 0-360
    final normalized = (bearing + 360) % 360;

    if (normalized >= 337.5 || normalized < 22.5) return 'North';
    if (normalized >= 22.5 && normalized < 67.5) return 'Northeast';
    if (normalized >= 67.5 && normalized < 112.5) return 'East';
    if (normalized >= 112.5 && normalized < 157.5) return 'Southeast';
    if (normalized >= 157.5 && normalized < 202.5) return 'South';
    if (normalized >= 202.5 && normalized < 247.5) return 'Southwest';
    if (normalized >= 247.5 && normalized < 292.5) return 'West';
    if (normalized >= 292.5 && normalized < 337.5) return 'Northwest';

    return 'Unknown';
  }

  /// Calculate user's current speed in km/h
  double calculateSpeed(
    LatLng previousLocation,
    LatLng currentLocation,
    Duration timeDifference,
  ) {
    final distanceMeters = _distance.as(
      LengthUnit.Meter,
      previousLocation,
      currentLocation,
    );

    final timeSeconds = timeDifference.inSeconds;
    if (timeSeconds == 0) return 0;

    final speedMps = distanceMeters / timeSeconds;
    final speedKph = speedMps * 3.6;

    return speedKph;
  }

  /// Check if user is moving (speed > 0.5 km/h)
  bool isMoving(double speedKph) {
    return speedKph > 0.5;
  }
}
