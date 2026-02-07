import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Status of the worker relative to the project geofence.
enum GeofenceStatus {
  /// GPS is being acquired.
  detecting,

  /// Worker is inside the geofence radius.
  inside,

  /// Worker is outside the geofence radius.
  outside,

  /// Location permission was denied by the user.
  permissionDenied,

  /// Location services are turned off on the device.
  serviceDisabled,

  /// Could not determine position (timeout, etc.).
  error,
}

class GeofenceResult {
  final GeofenceStatus status;

  /// Distance in metres from the site centre (null when status is not inside/outside).
  final double? distanceMetres;

  /// Current device latitude (null if position unavailable).
  final double? latitude;

  /// Current device longitude (null if position unavailable).
  final double? longitude;

  /// Human-readable message for UI display.
  final String message;

  const GeofenceResult({
    required this.status,
    this.distanceMetres,
    this.latitude,
    this.longitude,
    required this.message,
  });
}

class GeofenceService {
  /// Check the worker's position against a site centre + radius.
  ///
  /// [siteLat] / [siteLng] — centre of the geofence (from projects table).
  /// [radiusM] — allowed radius in metres (default 200).
  /// [bufferM] — extra tolerance to prevent flip-flopping at the boundary.
  Future<GeofenceResult> checkPosition({
    required double siteLat,
    required double siteLng,
    int radiusM = 200,
    int bufferM = 20,
  }) async {
    // 1. Check if location services are enabled
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return GeofenceResult(
        status: GeofenceStatus.serviceDisabled,
        message: 'Unable to check location services.',
      );
    }

    if (!serviceEnabled) {
      return const GeofenceResult(
        status: GeofenceStatus.serviceDisabled,
        message: 'Location services are turned off. Enable GPS in your device settings.',
      );
    }

    // 2. Check / request permission
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (e) {
      return GeofenceResult(
        status: GeofenceStatus.permissionDenied,
        message: 'Unable to request location permission.',
      );
    }

    if (permission == LocationPermission.denied) {
      return const GeofenceResult(
        status: GeofenceStatus.permissionDenied,
        message: 'Location permission denied. Tap to open settings.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const GeofenceResult(
        status: GeofenceStatus.permissionDenied,
        message: 'Location permission permanently denied. Open settings to enable.',
      );
    }

    // 3. Get current position
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('Geofence: position error — $e');
      return GeofenceResult(
        status: GeofenceStatus.error,
        message: 'Unable to get GPS position. Try again.',
      );
    }

    // 4. Calculate distance
    final distanceM = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      siteLat,
      siteLng,
    );

    final effectiveRadius = radiusM + bufferM;
    final isInside = distanceM <= effectiveRadius;

    final distRounded = distanceM.round();
    final distLabel = distRounded >= 1000
        ? '${(distanceM / 1000).toStringAsFixed(1)}km'
        : '${distRounded}m';

    return GeofenceResult(
      status: isInside ? GeofenceStatus.inside : GeofenceStatus.outside,
      distanceMetres: distanceM,
      latitude: position.latitude,
      longitude: position.longitude,
      message: isInside
          ? 'On Site — $distLabel from centre'
          : 'Off Site — $distLabel away',
    );
  }

  /// Open the device's location settings (useful when permission is denied).
  Future<bool> openSettings() => Geolocator.openAppSettings();

  /// Open the device's location *service* settings (GPS toggle).
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
