import 'package:flutter/foundation.dart';

import 'json_parsers.dart';

/// Candidate online tow-truck driver returned by
/// `public.find_nearest_drivers` RPC (Migration 004).
@immutable
class NearbyDriver {
  const NearbyDriver({
    required this.driverId,
    required this.winchId,
    required this.fullName,
    this.avatarUrl,
    required this.avgRating,
    required this.totalTrips,
    required this.winchBrand,
    required this.winchModel,
    required this.plateNumber,
    required this.currentLat,
    required this.currentLng,
    required this.distanceMeters,
    required this.etaMinutes,
  });

  final String driverId;
  final String winchId;
  final String fullName;
  final String? avatarUrl;
  final double avgRating;
  final int totalTrips;
  final String winchBrand;
  final String winchModel;
  final String plateNumber;
  final double currentLat;
  final double currentLng;
  final int distanceMeters;
  final int etaMinutes;

  factory NearbyDriver.fromJson(Map<String, dynamic> json) {
    return NearbyDriver(
      driverId: json['driver_id'] as String,
      winchId: json['winch_id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      avgRating: JsonParsers.asDouble(json['avg_rating'], field: 'avg_rating'),
      totalTrips: JsonParsers.asInt(json['total_trips'], field: 'total_trips'),
      winchBrand: json['winch_brand'] as String,
      winchModel: json['winch_model'] as String,
      plateNumber: json['plate_number'] as String,
      currentLat: JsonParsers.asDouble(
        json['current_lat'],
        field: 'current_lat',
      ),
      currentLng: JsonParsers.asDouble(
        json['current_lng'],
        field: 'current_lng',
      ),
      distanceMeters: JsonParsers.asInt(
        json['distance_meters'],
        field: 'distance_meters',
      ),
      etaMinutes: JsonParsers.asInt(json['eta_minutes'], field: 'eta_minutes'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'driver_id': driverId,
      'winch_id': winchId,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'avg_rating': avgRating,
      'total_trips': totalTrips,
      'winch_brand': winchBrand,
      'winch_model': winchModel,
      'plate_number': plateNumber,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'distance_meters': distanceMeters,
      'eta_minutes': etaMinutes,
    };
  }

  NearbyDriver copyWith({
    String? driverId,
    String? winchId,
    String? fullName,
    String? avatarUrl,
    double? avgRating,
    int? totalTrips,
    String? winchBrand,
    String? winchModel,
    String? plateNumber,
    double? currentLat,
    double? currentLng,
    int? distanceMeters,
    int? etaMinutes,
  }) {
    return NearbyDriver(
      driverId: driverId ?? this.driverId,
      winchId: winchId ?? this.winchId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avgRating: avgRating ?? this.avgRating,
      totalTrips: totalTrips ?? this.totalTrips,
      winchBrand: winchBrand ?? this.winchBrand,
      winchModel: winchModel ?? this.winchModel,
      plateNumber: plateNumber ?? this.plateNumber,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      etaMinutes: etaMinutes ?? this.etaMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyDriver &&
          runtimeType == other.runtimeType &&
          driverId == other.driverId &&
          winchId == other.winchId &&
          fullName == other.fullName &&
          avatarUrl == other.avatarUrl &&
          avgRating == other.avgRating &&
          totalTrips == other.totalTrips &&
          winchBrand == other.winchBrand &&
          winchModel == other.winchModel &&
          plateNumber == other.plateNumber &&
          currentLat == other.currentLat &&
          currentLng == other.currentLng &&
          distanceMeters == other.distanceMeters &&
          etaMinutes == other.etaMinutes;

  @override
  int get hashCode => Object.hash(
        driverId,
        winchId,
        fullName,
        avatarUrl,
        avgRating,
        totalTrips,
        winchBrand,
        winchModel,
        plateNumber,
        currentLat,
        currentLng,
        distanceMeters,
        etaMinutes,
      );
}
