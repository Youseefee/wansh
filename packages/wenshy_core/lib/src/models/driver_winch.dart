import 'package:flutter/foundation.dart';

import 'json_parsers.dart';
import 'winch_type.dart';

/// Tow-truck vehicle operated by a driver matching `public.driver_winches`
/// (Migration 002).
@immutable
class DriverWinch {
  const DriverWinch({
    required this.id,
    required this.driverId,
    required this.winchTypeId,
    required this.plateNumber,
    required this.brand,
    required this.model,
    this.year,
    this.color,
    this.maxCapacityTons,
    this.winchLicenseNumber,
    this.winchLicenseExpiry,
    this.photoPaths = const <String>[],
    this.isVerified = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.winchType,
  });

  final String id;
  final String driverId;
  final String winchTypeId;
  final String plateNumber;
  final String brand;
  final String model;
  final int? year;
  final String? color;
  final double? maxCapacityTons;
  final String? winchLicenseNumber;
  final DateTime? winchLicenseExpiry;
  final List<String> photoPaths;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional joined `winch_types` record when selected via `select('*, winch_types(*)')`.
  final WinchType? winchType;

  String get displayLabel =>
      year != null ? '$brand $model ($year)' : '$brand $model';

  factory DriverWinch.fromJson(Map<String, dynamic> json) {
    final nestedType = json['winch_types'];
    return DriverWinch(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      winchTypeId: json['winch_type_id'] as String,
      plateNumber: json['plate_number'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: JsonParsers.asNullableInt(json['year']),
      color: json['color'] as String?,
      maxCapacityTons: JsonParsers.asNullableDouble(json['max_capacity_tons']),
      winchLicenseNumber: json['winch_license_number'] as String?,
      winchLicenseExpiry:
          JsonParsers.asNullableDateTime(json['winch_license_expiry']),
      photoPaths: JsonParsers.asStringList(json['photo_paths']),
      isVerified: JsonParsers.asBool(json['is_verified'], defaultValue: false),
      isActive: JsonParsers.asBool(json['is_active'], defaultValue: true),
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
      updatedAt: JsonParsers.asDateTime(
        json['updated_at'],
        field: 'updated_at',
      ),
      winchType: nestedType is Map<String, dynamic>
          ? WinchType.fromJson(nestedType)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'driver_id': driverId,
      'winch_type_id': winchTypeId,
      'plate_number': plateNumber,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'max_capacity_tons': maxCapacityTons,
      'winch_license_number': winchLicenseNumber,
      'winch_license_expiry': JsonParsers.toSqlDate(winchLicenseExpiry),
      'photo_paths': photoPaths,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Payload suitable for inserting into `public.driver_winches`.
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'driver_id': driverId,
      'winch_type_id': winchTypeId,
      'plate_number': plateNumber,
      'brand': brand,
      'model': model,
      if (year != null) 'year': year,
      if (color != null) 'color': color,
      if (maxCapacityTons != null) 'max_capacity_tons': maxCapacityTons,
      if (winchLicenseNumber != null)
        'winch_license_number': winchLicenseNumber,
      if (winchLicenseExpiry != null)
        'winch_license_expiry': JsonParsers.toSqlDate(winchLicenseExpiry),
      'photo_paths': photoPaths,
      'is_active': isActive,
    };
  }

  DriverWinch copyWith({
    String? id,
    String? driverId,
    String? winchTypeId,
    String? plateNumber,
    String? brand,
    String? model,
    int? year,
    String? color,
    double? maxCapacityTons,
    String? winchLicenseNumber,
    DateTime? winchLicenseExpiry,
    List<String>? photoPaths,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    WinchType? winchType,
  }) {
    return DriverWinch(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      winchTypeId: winchTypeId ?? this.winchTypeId,
      plateNumber: plateNumber ?? this.plateNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      maxCapacityTons: maxCapacityTons ?? this.maxCapacityTons,
      winchLicenseNumber: winchLicenseNumber ?? this.winchLicenseNumber,
      winchLicenseExpiry: winchLicenseExpiry ?? this.winchLicenseExpiry,
      photoPaths: photoPaths ?? this.photoPaths,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      winchType: winchType ?? this.winchType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverWinch &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          driverId == other.driverId &&
          winchTypeId == other.winchTypeId &&
          plateNumber == other.plateNumber &&
          brand == other.brand &&
          model == other.model &&
          year == other.year &&
          color == other.color &&
          maxCapacityTons == other.maxCapacityTons &&
          winchLicenseNumber == other.winchLicenseNumber &&
          winchLicenseExpiry == other.winchLicenseExpiry &&
          JsonParsers.stringListEquals(photoPaths, other.photoPaths) &&
          isVerified == other.isVerified &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          winchType == other.winchType;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        driverId,
        winchTypeId,
        plateNumber,
        brand,
        model,
        year,
        color,
        maxCapacityTons,
        winchLicenseNumber,
        winchLicenseExpiry,
        Object.hashAll(photoPaths),
        isVerified,
        isActive,
        createdAt,
        updatedAt,
        winchType,
      ]);
}
