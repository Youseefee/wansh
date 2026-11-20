import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';

/// Saved customer vehicle matching `public.customer_vehicles` (Migration 002).
@immutable
class CustomerVehicle {
  const CustomerVehicle({
    required this.id,
    required this.customerId,
    required this.make,
    required this.model,
    this.year,
    this.color,
    required this.plateNumber,
    this.vehicleCategory = VehicleCategory.sedan,
    this.notes,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String make;
  final String model;
  final int? year;
  final String? color;
  final String plateNumber;
  final VehicleCategory vehicleCategory;
  final String? notes;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Concise display label, e.g. `"Toyota Corolla (2022)"`.
  String get displayLabel =>
      year != null ? '$make $model ($year)' : '$make $model';

  factory CustomerVehicle.fromJson(Map<String, dynamic> json) {
    return CustomerVehicle(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: JsonParsers.asNullableInt(json['year']),
      color: json['color'] as String?,
      plateNumber: json['plate_number'] as String,
      vehicleCategory:
          VehicleCategory.tryFromJson(json['vehicle_category']) ??
              VehicleCategory.sedan,
      notes: json['notes'] as String?,
      isDefault: JsonParsers.asBool(json['is_default'], defaultValue: false),
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
      updatedAt: JsonParsers.asDateTime(
        json['updated_at'],
        field: 'updated_at',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'customer_id': customerId,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plate_number': plateNumber,
      'vehicle_category': vehicleCategory.toJson(),
      'notes': notes,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Payload suitable for inserting into `public.customer_vehicles`.
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'customer_id': customerId,
      'make': make,
      'model': model,
      if (year != null) 'year': year,
      if (color != null) 'color': color,
      'plate_number': plateNumber,
      'vehicle_category': vehicleCategory.toJson(),
      if (notes != null) 'notes': notes,
      'is_default': isDefault,
    };
  }

  CustomerVehicle copyWith({
    String? id,
    String? customerId,
    String? make,
    String? model,
    int? year,
    String? color,
    String? plateNumber,
    VehicleCategory? vehicleCategory,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerVehicle(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerVehicle &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          customerId == other.customerId &&
          make == other.make &&
          model == other.model &&
          year == other.year &&
          color == other.color &&
          plateNumber == other.plateNumber &&
          vehicleCategory == other.vehicleCategory &&
          notes == other.notes &&
          isDefault == other.isDefault &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        customerId,
        make,
        model,
        year,
        color,
        plateNumber,
        vehicleCategory,
        notes,
        isDefault,
        createdAt,
        updatedAt,
      );
}
