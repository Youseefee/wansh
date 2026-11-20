import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Normalized GPS reading bounded to match Wenshy SQL constraints
/// (`current_heading` in `[0, 360]`, `current_speed_kmh >= 0`).
@immutable
class DriverPositionData {
  const DriverPositionData({
    required this.lat,
    required this.lng,
    this.heading,
    this.speedKmh,
    this.timestamp,
  });

  final double lat;
  final double lng;
  final double? heading;
  final double? speedKmh;
  final DateTime? timestamp;

  factory DriverPositionData.fromGeolocator(Position position) {
    final rawHeading = position.heading;
    final double? safeHeading =
        rawHeading.isFinite && rawHeading >= 0 && rawHeading <= 360
            ? rawHeading
            : null;

    final rawSpeed = position.speed;
    final double? safeSpeedKmh =
        rawSpeed.isFinite && rawSpeed >= 0 ? rawSpeed * 3.6 : null;

    return DriverPositionData(
      lat: position.latitude,
      lng: position.longitude,
      heading: safeHeading,
      speedKmh: safeSpeedKmh,
      timestamp: position.timestamp,
    );
  }
}

/// Exception thrown when device location services or permissions are denied.
class DriverLocationException implements Exception {
  const DriverLocationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DriverLocationException($code): $message';
}

/// Abstract GPS source so ViewModels can be unit-tested without device channels.
abstract class DriverLocationSource {
  Future<DriverPositionData> getCurrentPosition();

  Stream<DriverPositionData> getPositionStream({
    int distanceFilterMeters = 5,
    Duration interval = const Duration(seconds: 2),
  });
}

/// Production [DriverLocationSource] backed by `geolocator`.
class GeolocatorDriverLocationSource implements DriverLocationSource {
  const GeolocatorDriverLocationSource();

  Future<void> _ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const DriverLocationException(
        'location_service_disabled',
        'Location services are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const DriverLocationException(
        'permission_denied',
        'Location permission denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const DriverLocationException(
        'permission_denied_forever',
        'Location permission permanently denied.',
      );
    }
  }

  @override
  Future<DriverPositionData> getCurrentPosition() async {
    await _ensurePermissions();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return DriverPositionData.fromGeolocator(position);
  }

  /// Builds platform-appropriate [LocationSettings] with an Android foreground
  /// notification service (wake lock + ongoing notification) and iOS background
  /// location updates so live GPS streaming continues reliably when the driver
  /// switches to Google Maps / Waze or locks the screen.
  static LocationSettings buildPositionStreamSettings({
    required TargetPlatform platform,
    int distanceFilterMeters = 5,
    Duration interval = const Duration(seconds: 2),
  }) {
    if (platform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'ونشي للسائقين • Wenshy Driver',
          notificationText:
              'جاري بث موقعك المباشر لرحلة الإنقاذ • Live trip GPS active',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (platform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
  }

  @override
  Stream<DriverPositionData> getPositionStream({
    int distanceFilterMeters = 5,
    Duration interval = const Duration(seconds: 2),
  }) async* {
    await _ensurePermissions();
    final settings = buildPositionStreamSettings(
      platform: defaultTargetPlatform,
      distanceFilterMeters: distanceFilterMeters,
      interval: interval,
    );

    yield* Geolocator.getPositionStream(locationSettings: settings)
        .map(DriverPositionData.fromGeolocator);
  }
}
