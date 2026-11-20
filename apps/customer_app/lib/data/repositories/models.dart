import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Represents a photo selected locally before upload to Supabase Storage.
class SelectedPhotoBytes {
  const SelectedPhotoBytes({
    required this.fileName,
    required this.bytes,
    this.contentType = 'image/jpeg',
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;
}

/// Selected map coordinate pair, human-readable address, and optional road
/// route metrics passed from the Home Map into the Rescue Request flow.
class RouteSelection {
  const RouteSelection({
    required this.pickupPoint,
    required this.pickupAddress,
    required this.dropoffPoint,
    required this.dropoffAddress,
    this.initialWinchTypeId,
    this.routeDistanceKm,
    this.routeDurationMinutes,
    this.routePolyline = const <LatLng>[],
  });

  final LatLng pickupPoint;
  final String pickupAddress;
  final LatLng dropoffPoint;
  final String dropoffAddress;
  final String? initialWinchTypeId;
  final double? routeDistanceKm;
  final int? routeDurationMinutes;
  final List<LatLng> routePolyline;
}

/// Interactive map selection target on the Home Map.
enum MapPickMode { pickup, dropoff }
