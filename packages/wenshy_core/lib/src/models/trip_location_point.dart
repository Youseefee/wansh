import 'package:flutter/foundation.dart';

import 'json_parsers.dart';

/// GPS breadcrumb matching `public.trip_location_history` (Migration 002)
/// and ephemeral `driver_location` Realtime broadcasts on `trip:<request_id>`.
@immutable
class TripLocationPoint {
  const TripLocationPoint({
    this.id,
    this.requestId,
    this.driverId,
    required this.lat,
    required this.lng,
    this.heading,
    this.speedKmh,
    this.recordedAt,
  });

  final int? id;
  final String? requestId;
  final String? driverId;
  final double lat;
  final double lng;
  final double? heading;
  final double? speedKmh;
  final DateTime? recordedAt;

  factory TripLocationPoint.fromJson(Map<String, dynamic> json) {
    return TripLocationPoint(
      id: JsonParsers.asNullableInt(json['id']),
      requestId: json['request_id'] as String?,
      driverId: json['driver_id'] as String?,
      lat: JsonParsers.asDouble(json['lat'], field: 'lat'),
      lng: JsonParsers.asDouble(json['lng'], field: 'lng'),
      heading: JsonParsers.asNullableDouble(json['heading']),
      speedKmh: JsonParsers.asNullableDouble(
        json['speed_kmh'] ?? json['speed'],
      ),
      recordedAt: JsonParsers.asNullableDateTime(json['recorded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (requestId != null) 'request_id': requestId,
      if (driverId != null) 'driver_id': driverId,
      'lat': lat,
      'lng': lng,
      if (heading != null) 'heading': heading,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (recordedAt != null) 'recorded_at': recordedAt!.toIso8601String(),
    };
  }

  /// Compact payload for ephemeral `driver_location` Realtime broadcasts.
  Map<String, dynamic> toBroadcastJson() {
    return <String, dynamic>{
      'lat': lat,
      'lng': lng,
      if (heading != null) 'heading': heading,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      'recorded_at': (recordedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripLocationPoint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestId == other.requestId &&
          driverId == other.driverId &&
          lat == other.lat &&
          lng == other.lng &&
          heading == other.heading &&
          speedKmh == other.speedKmh &&
          recordedAt == other.recordedAt;

  @override
  int get hashCode => Object.hash(
        id,
        requestId,
        driverId,
        lat,
        lng,
        heading,
        speedKmh,
        recordedAt,
      );
}
