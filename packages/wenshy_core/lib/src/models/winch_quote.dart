import 'package:flutter/foundation.dart';

import 'json_parsers.dart';

/// Server-computed price & distance quotation returned by
/// `public.calculate_winch_quote` RPC (Migration 004).
@immutable
class WinchQuote {
  const WinchQuote({
    required this.winchTypeId,
    required this.winchCode,
    required this.winchNameAr,
    required this.winchNameEn,
    required this.geodesicDistanceKm,
    required this.estimatedDistanceKm,
    required this.estimatedDurationMin,
    required this.baseFare,
    required this.pricePerKm,
    required this.minimumFare,
    required this.surgeMultiplier,
    required this.estimatedPrice,
    required this.minPriceRange,
    required this.maxPriceRange,
    this.currency = 'EGP',
  });

  final String winchTypeId;
  final String winchCode;
  final String winchNameAr;
  final String winchNameEn;
  final double geodesicDistanceKm;
  final double estimatedDistanceKm;
  final int estimatedDurationMin;
  final double baseFare;
  final double pricePerKm;
  final double minimumFare;
  final double surgeMultiplier;
  final double estimatedPrice;
  final double minPriceRange;
  final double maxPriceRange;
  final String currency;

  String localizedWinchName(String locale) =>
      locale.toLowerCase().startsWith('ar') ? winchNameAr : winchNameEn;

  factory WinchQuote.fromJson(Map<String, dynamic> json) {
    return WinchQuote(
      winchTypeId: json['winch_type_id'] as String,
      winchCode: json['winch_code'] as String,
      winchNameAr: json['winch_name_ar'] as String,
      winchNameEn: json['winch_name_en'] as String,
      geodesicDistanceKm: JsonParsers.asDouble(
        json['geodesic_distance_km'],
        field: 'geodesic_distance_km',
      ),
      estimatedDistanceKm: JsonParsers.asDouble(
        json['estimated_distance_km'],
        field: 'estimated_distance_km',
      ),
      estimatedDurationMin: JsonParsers.asInt(
        json['estimated_duration_min'],
        field: 'estimated_duration_min',
      ),
      baseFare: JsonParsers.asDouble(json['base_fare'], field: 'base_fare'),
      pricePerKm: JsonParsers.asDouble(
        json['price_per_km'],
        field: 'price_per_km',
      ),
      minimumFare: JsonParsers.asDouble(
        json['minimum_fare'],
        field: 'minimum_fare',
      ),
      surgeMultiplier: JsonParsers.asDouble(
        json['surge_multiplier'],
        field: 'surge_multiplier',
      ),
      estimatedPrice: JsonParsers.asDouble(
        json['estimated_price'],
        field: 'estimated_price',
      ),
      minPriceRange: JsonParsers.asDouble(
        json['min_price_range'],
        field: 'min_price_range',
      ),
      maxPriceRange: JsonParsers.asDouble(
        json['max_price_range'],
        field: 'max_price_range',
      ),
      currency: (json['currency'] as String?) ?? 'EGP',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'winch_type_id': winchTypeId,
      'winch_code': winchCode,
      'winch_name_ar': winchNameAr,
      'winch_name_en': winchNameEn,
      'geodesic_distance_km': geodesicDistanceKm,
      'estimated_distance_km': estimatedDistanceKm,
      'estimated_duration_min': estimatedDurationMin,
      'base_fare': baseFare,
      'price_per_km': pricePerKm,
      'minimum_fare': minimumFare,
      'surge_multiplier': surgeMultiplier,
      'estimated_price': estimatedPrice,
      'min_price_range': minPriceRange,
      'max_price_range': maxPriceRange,
      'currency': currency,
    };
  }

  WinchQuote copyWith({
    String? winchTypeId,
    String? winchCode,
    String? winchNameAr,
    String? winchNameEn,
    double? geodesicDistanceKm,
    double? estimatedDistanceKm,
    int? estimatedDurationMin,
    double? baseFare,
    double? pricePerKm,
    double? minimumFare,
    double? surgeMultiplier,
    double? estimatedPrice,
    double? minPriceRange,
    double? maxPriceRange,
    String? currency,
  }) {
    return WinchQuote(
      winchTypeId: winchTypeId ?? this.winchTypeId,
      winchCode: winchCode ?? this.winchCode,
      winchNameAr: winchNameAr ?? this.winchNameAr,
      winchNameEn: winchNameEn ?? this.winchNameEn,
      geodesicDistanceKm: geodesicDistanceKm ?? this.geodesicDistanceKm,
      estimatedDistanceKm: estimatedDistanceKm ?? this.estimatedDistanceKm,
      estimatedDurationMin: estimatedDurationMin ?? this.estimatedDurationMin,
      baseFare: baseFare ?? this.baseFare,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      minimumFare: minimumFare ?? this.minimumFare,
      surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      minPriceRange: minPriceRange ?? this.minPriceRange,
      maxPriceRange: maxPriceRange ?? this.maxPriceRange,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinchQuote &&
          runtimeType == other.runtimeType &&
          winchTypeId == other.winchTypeId &&
          winchCode == other.winchCode &&
          winchNameAr == other.winchNameAr &&
          winchNameEn == other.winchNameEn &&
          geodesicDistanceKm == other.geodesicDistanceKm &&
          estimatedDistanceKm == other.estimatedDistanceKm &&
          estimatedDurationMin == other.estimatedDurationMin &&
          baseFare == other.baseFare &&
          pricePerKm == other.pricePerKm &&
          minimumFare == other.minimumFare &&
          surgeMultiplier == other.surgeMultiplier &&
          estimatedPrice == other.estimatedPrice &&
          minPriceRange == other.minPriceRange &&
          maxPriceRange == other.maxPriceRange &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(
        winchTypeId,
        winchCode,
        winchNameAr,
        winchNameEn,
        geodesicDistanceKm,
        estimatedDistanceKm,
        estimatedDurationMin,
        baseFare,
        pricePerKm,
        minimumFare,
        surgeMultiplier,
        estimatedPrice,
        minPriceRange,
        maxPriceRange,
        currency,
      );
}
