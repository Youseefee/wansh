import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';
import 'user_profile.dart';

/// Tow-truck driver record matching `public.drivers` (Migration 002).
@immutable
class DriverProfile {
  const DriverProfile({
    required this.id,
    this.nationalIdNumber,
    this.licenseNumber,
    this.licenseExpiry,
    this.approvalStatus = DriverApprovalStatus.pending,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.isOnline = false,
    this.isAvailable = true,
    this.currentLat,
    this.currentLng,
    this.currentHeading,
    this.currentSpeedKmh,
    this.lastLocationAt,
    this.avgRating = 5.0,
    this.totalRatings = 0,
    this.totalTrips = 0,
    this.totalEarnings = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.profile,
  });

  final String id;
  final String? nationalIdNumber;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final DriverApprovalStatus approvalStatus;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final bool isOnline;
  final bool isAvailable;
  final double? currentLat;
  final double? currentLng;
  final double? currentHeading;
  final double? currentSpeedKmh;
  final DateTime? lastLocationAt;
  final double avgRating;
  final int totalRatings;
  final int totalTrips;
  final double totalEarnings;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional joined `profiles` record when selected via `select('*, profiles(*)')`.
  final UserProfile? profile;

  bool get isApproved => approvalStatus == DriverApprovalStatus.approved;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    final nestedProfile = json['profiles'];
    return DriverProfile(
      id: json['id'] as String,
      nationalIdNumber: json['national_id_number'] as String?,
      licenseNumber: json['license_number'] as String?,
      licenseExpiry: JsonParsers.asNullableDateTime(json['license_expiry']),
      approvalStatus:
          DriverApprovalStatus.tryFromJson(json['approval_status']) ??
              DriverApprovalStatus.pending,
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: JsonParsers.asNullableDateTime(json['reviewed_at']),
      isOnline: JsonParsers.asBool(json['is_online'], defaultValue: false),
      isAvailable: JsonParsers.asBool(json['is_available'], defaultValue: true),
      currentLat: JsonParsers.asNullableDouble(json['current_lat']),
      currentLng: JsonParsers.asNullableDouble(json['current_lng']),
      currentHeading: JsonParsers.asNullableDouble(json['current_heading']),
      currentSpeedKmh: JsonParsers.asNullableDouble(json['current_speed_kmh']),
      lastLocationAt: JsonParsers.asNullableDateTime(json['last_location_at']),
      avgRating: JsonParsers.asNullableDouble(json['avg_rating']) ?? 5.0,
      totalRatings: JsonParsers.asNullableInt(json['total_ratings']) ?? 0,
      totalTrips: JsonParsers.asNullableInt(json['total_trips']) ?? 0,
      totalEarnings:
          JsonParsers.asNullableDouble(json['total_earnings']) ?? 0.0,
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
      updatedAt: JsonParsers.asDateTime(
        json['updated_at'],
        field: 'updated_at',
      ),
      profile: nestedProfile is Map<String, dynamic>
          ? UserProfile.fromJson(nestedProfile)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'national_id_number': nationalIdNumber,
      'license_number': licenseNumber,
      'license_expiry': JsonParsers.toSqlDate(licenseExpiry),
      'approval_status': approvalStatus.toJson(),
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'is_online': isOnline,
      'is_available': isAvailable,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'current_heading': currentHeading,
      'current_speed_kmh': currentSpeedKmh,
      'last_location_at': lastLocationAt?.toIso8601String(),
      'avg_rating': avgRating,
      'total_ratings': totalRatings,
      'total_trips': totalTrips,
      'total_earnings': totalEarnings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DriverProfile copyWith({
    String? id,
    String? nationalIdNumber,
    String? licenseNumber,
    DateTime? licenseExpiry,
    DriverApprovalStatus? approvalStatus,
    String? rejectionReason,
    String? reviewedBy,
    DateTime? reviewedAt,
    bool? isOnline,
    bool? isAvailable,
    double? currentLat,
    double? currentLng,
    double? currentHeading,
    double? currentSpeedKmh,
    DateTime? lastLocationAt,
    double? avgRating,
    int? totalRatings,
    int? totalTrips,
    double? totalEarnings,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? profile,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      currentHeading: currentHeading ?? this.currentHeading,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      avgRating: avgRating ?? this.avgRating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalTrips: totalTrips ?? this.totalTrips,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile ?? this.profile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nationalIdNumber == other.nationalIdNumber &&
          licenseNumber == other.licenseNumber &&
          licenseExpiry == other.licenseExpiry &&
          approvalStatus == other.approvalStatus &&
          rejectionReason == other.rejectionReason &&
          reviewedBy == other.reviewedBy &&
          reviewedAt == other.reviewedAt &&
          isOnline == other.isOnline &&
          isAvailable == other.isAvailable &&
          currentLat == other.currentLat &&
          currentLng == other.currentLng &&
          currentHeading == other.currentHeading &&
          currentSpeedKmh == other.currentSpeedKmh &&
          lastLocationAt == other.lastLocationAt &&
          avgRating == other.avgRating &&
          totalRatings == other.totalRatings &&
          totalTrips == other.totalTrips &&
          totalEarnings == other.totalEarnings &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          profile == other.profile;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        nationalIdNumber,
        licenseNumber,
        licenseExpiry,
        approvalStatus,
        rejectionReason,
        reviewedBy,
        reviewedAt,
        isOnline,
        isAvailable,
        currentLat,
        currentLng,
        currentHeading,
        currentSpeedKmh,
        lastLocationAt,
        avgRating,
        totalRatings,
        totalTrips,
        totalEarnings,
        createdAt,
        updatedAt,
        profile,
      ]);
}
