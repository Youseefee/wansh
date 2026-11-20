import 'package:flutter/foundation.dart';

import 'json_parsers.dart';

/// Tow truck category & pricing catalog entry matching `public.winch_types`
/// (Migration 002 & `supabase/seed.sql`).
@immutable
class WinchType {
  const WinchType({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.baseFare,
    required this.pricePerKm,
    required this.minimumFare,
    this.roadFactor = 1.25,
    this.surgeMultiplier = 1.00,
    this.maxWeightTons,
    this.iconName,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final double baseFare;
  final double pricePerKm;
  final double minimumFare;
  final double roadFactor;
  final double surgeMultiplier;
  final double? maxWeightTons;
  final String? iconName;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns [nameAr] when [locale] starts with `'ar'`, otherwise [nameEn].
  String localizedName(String locale) =>
      locale.toLowerCase().startsWith('ar') ? nameAr : nameEn;

  /// Returns [descriptionAr] when [locale] starts with `'ar'`, otherwise
  /// [descriptionEn].
  String? localizedDescription(String locale) =>
      locale.toLowerCase().startsWith('ar') ? descriptionAr : descriptionEn;

  factory WinchType.fromJson(Map<String, dynamic> json) {
    return WinchType(
      id: json['id'] as String,
      code: json['code'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      baseFare: JsonParsers.asDouble(json['base_fare'], field: 'base_fare'),
      pricePerKm: JsonParsers.asDouble(
        json['price_per_km'],
        field: 'price_per_km',
      ),
      minimumFare: JsonParsers.asDouble(
        json['minimum_fare'],
        field: 'minimum_fare',
      ),
      roadFactor:
          JsonParsers.asNullableDouble(json['road_factor']) ?? 1.25,
      surgeMultiplier:
          JsonParsers.asNullableDouble(json['surge_multiplier']) ?? 1.00,
      maxWeightTons: JsonParsers.asNullableDouble(json['max_weight_tons']),
      iconName: json['icon_name'] as String?,
      sortOrder: JsonParsers.asNullableInt(json['sort_order']) ?? 0,
      isActive: JsonParsers.asBool(json['is_active'], defaultValue: true),
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
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'base_fare': baseFare,
      'price_per_km': pricePerKm,
      'minimum_fare': minimumFare,
      'road_factor': roadFactor,
      'surge_multiplier': surgeMultiplier,
      'max_weight_tons': maxWeightTons,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WinchType copyWith({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? descriptionEn,
    double? baseFare,
    double? pricePerKm,
    double? minimumFare,
    double? roadFactor,
    double? surgeMultiplier,
    double? maxWeightTons,
    String? iconName,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WinchType(
      id: id ?? this.id,
      code: code ?? this.code,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      baseFare: baseFare ?? this.baseFare,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      minimumFare: minimumFare ?? this.minimumFare,
      roadFactor: roadFactor ?? this.roadFactor,
      surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
      maxWeightTons: maxWeightTons ?? this.maxWeightTons,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinchType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          nameAr == other.nameAr &&
          nameEn == other.nameEn &&
          descriptionAr == other.descriptionAr &&
          descriptionEn == other.descriptionEn &&
          baseFare == other.baseFare &&
          pricePerKm == other.pricePerKm &&
          minimumFare == other.minimumFare &&
          roadFactor == other.roadFactor &&
          surgeMultiplier == other.surgeMultiplier &&
          maxWeightTons == other.maxWeightTons &&
          iconName == other.iconName &&
          sortOrder == other.sortOrder &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        code,
        nameAr,
        nameEn,
        descriptionAr,
        descriptionEn,
        baseFare,
        pricePerKm,
        minimumFare,
        roadFactor,
        surgeMultiplier,
        maxWeightTons,
        iconName,
        sortOrder,
        isActive,
        createdAt,
        updatedAt,
      );
}
