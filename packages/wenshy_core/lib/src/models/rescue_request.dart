import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';
import 'winch_quote.dart';

/// Core towing trip record matching `public.rescue_requests` (Migration 002).
@immutable
class RescueRequest {
  const RescueRequest({
    required this.id,
    required this.requestCode,
    required this.customerId,
    this.driverId,
    required this.winchTypeId,
    this.winchId,
    this.customerVehicleId,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehiclePlate,
    this.vehicleCategory = VehicleCategory.sedan,
    this.breakdownReason,
    this.breakdownNotes,
    this.breakdownPhotoPaths = const <String>[],
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.geodesicDistanceKm,
    required this.estimatedDistanceKm,
    this.estimatedDurationMin,
    required this.baseFareSnapshot,
    required this.pricePerKmSnapshot,
    required this.estimatedPrice,
    this.finalPrice,
    this.currency = 'EGP',
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.pending,
    this.status = TripStatus.searching,
    this.currentWave = 1,
    this.cancellationReason,
    this.cancelledBy,
    this.acceptedAt,
    this.enRouteAt,
    this.arrivedAt,
    this.loadedAt,
    this.dropoffStartedAt,
    this.completedAt,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String requestCode;
  final String customerId;
  final String? driverId;
  final String winchTypeId;
  final String? winchId;
  final String? customerVehicleId;

  // Vehicle snapshot
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? vehiclePlate;
  final VehicleCategory vehicleCategory;

  // Breakdown details
  final String? breakdownReason;
  final String? breakdownNotes;
  final List<String> breakdownPhotoPaths;

  // Coordinates & addresses
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;

  // Distance & pricing
  final double geodesicDistanceKm;
  final double estimatedDistanceKm;
  final int? estimatedDurationMin;
  final double baseFareSnapshot;
  final double pricePerKmSnapshot;
  final double estimatedPrice;
  final double? finalPrice;
  final String currency;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;

  // Lifecycle & timestamps
  final TripStatus status;
  final int currentWave;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? acceptedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? loadedAt;
  final DateTime? dropoffStartedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Effective trip price ([finalPrice] after delivery, otherwise
  /// [estimatedPrice]).
  double get displayPrice => finalPrice ?? estimatedPrice;

  /// Human-readable vehicle summary if vehicle details are present.
  String? get vehicleSummary {
    final parts = <String>[
      if (vehicleMake != null && vehicleMake!.trim().isNotEmpty)
        vehicleMake!.trim(),
      if (vehicleModel != null && vehicleModel!.trim().isNotEmpty)
        vehicleModel!.trim(),
      if (vehicleYear != null) '($vehicleYear)',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  factory RescueRequest.fromJson(Map<String, dynamic> json) {
    return RescueRequest(
      id: json['id'] as String,
      requestCode: json['request_code'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String?,
      winchTypeId: json['winch_type_id'] as String,
      winchId: json['winch_id'] as String?,
      customerVehicleId: json['customer_vehicle_id'] as String?,
      vehicleMake: json['vehicle_make'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleYear: JsonParsers.asNullableInt(json['vehicle_year']),
      vehicleColor: json['vehicle_color'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleCategory:
          VehicleCategory.tryFromJson(json['vehicle_category']) ??
              VehicleCategory.sedan,
      breakdownReason: json['breakdown_reason'] as String?,
      breakdownNotes: json['breakdown_notes'] as String?,
      breakdownPhotoPaths:
          JsonParsers.asStringList(json['breakdown_photo_paths']),
      pickupLat: JsonParsers.asDouble(json['pickup_lat'], field: 'pickup_lat'),
      pickupLng: JsonParsers.asDouble(json['pickup_lng'], field: 'pickup_lng'),
      pickupAddress: json['pickup_address'] as String,
      dropoffLat:
          JsonParsers.asDouble(json['dropoff_lat'], field: 'dropoff_lat'),
      dropoffLng:
          JsonParsers.asDouble(json['dropoff_lng'], field: 'dropoff_lng'),
      dropoffAddress: json['dropoff_address'] as String,
      geodesicDistanceKm: JsonParsers.asDouble(
        json['geodesic_distance_km'],
        field: 'geodesic_distance_km',
      ),
      estimatedDistanceKm: JsonParsers.asDouble(
        json['estimated_distance_km'],
        field: 'estimated_distance_km',
      ),
      estimatedDurationMin:
          JsonParsers.asNullableInt(json['estimated_duration_min']),
      baseFareSnapshot: JsonParsers.asDouble(
        json['base_fare_snapshot'],
        field: 'base_fare_snapshot',
      ),
      pricePerKmSnapshot: JsonParsers.asDouble(
        json['price_per_km_snapshot'],
        field: 'price_per_km_snapshot',
      ),
      estimatedPrice: JsonParsers.asDouble(
        json['estimated_price'],
        field: 'estimated_price',
      ),
      finalPrice: JsonParsers.asNullableDouble(json['final_price']),
      currency: (json['currency'] as String?) ?? 'EGP',
      paymentMethod: PaymentMethod.tryFromJson(json['payment_method']) ??
          PaymentMethod.cash,
      paymentStatus: PaymentStatus.tryFromJson(json['payment_status']) ??
          PaymentStatus.pending,
      status: TripStatus.tryFromJson(json['status']) ?? TripStatus.searching,
      currentWave: JsonParsers.asNullableInt(json['current_wave']) ?? 1,
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      acceptedAt: JsonParsers.asNullableDateTime(json['accepted_at']),
      enRouteAt: JsonParsers.asNullableDateTime(json['en_route_at']),
      arrivedAt: JsonParsers.asNullableDateTime(json['arrived_at']),
      loadedAt: JsonParsers.asNullableDateTime(json['loaded_at']),
      dropoffStartedAt:
          JsonParsers.asNullableDateTime(json['dropoff_started_at']),
      completedAt: JsonParsers.asNullableDateTime(json['completed_at']),
      cancelledAt: JsonParsers.asNullableDateTime(json['cancelled_at']),
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
      'request_code': requestCode,
      'customer_id': customerId,
      'driver_id': driverId,
      'winch_type_id': winchTypeId,
      'winch_id': winchId,
      'customer_vehicle_id': customerVehicleId,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'vehicle_plate': vehiclePlate,
      'vehicle_category': vehicleCategory.toJson(),
      'breakdown_reason': breakdownReason,
      'breakdown_notes': breakdownNotes,
      'breakdown_photo_paths': breakdownPhotoPaths,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'dropoff_address': dropoffAddress,
      'geodesic_distance_km': geodesicDistanceKm,
      'estimated_distance_km': estimatedDistanceKm,
      'estimated_duration_min': estimatedDurationMin,
      'base_fare_snapshot': baseFareSnapshot,
      'price_per_km_snapshot': pricePerKmSnapshot,
      'estimated_price': estimatedPrice,
      'final_price': finalPrice,
      'currency': currency,
      'payment_method': paymentMethod.toJson(),
      'payment_status': paymentStatus.toJson(),
      'status': status.toJson(),
      'current_wave': currentWave,
      'cancellation_reason': cancellationReason,
      'cancelled_by': cancelledBy,
      'accepted_at': acceptedAt?.toIso8601String(),
      'en_route_at': enRouteAt?.toIso8601String(),
      'arrived_at': arrivedAt?.toIso8601String(),
      'loaded_at': loadedAt?.toIso8601String(),
      'dropoff_started_at': dropoffStartedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RescueRequest copyWith({
    String? id,
    String? requestCode,
    String? customerId,
    String? driverId,
    String? winchTypeId,
    String? winchId,
    String? customerVehicleId,
    String? vehicleMake,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? vehiclePlate,
    VehicleCategory? vehicleCategory,
    String? breakdownReason,
    String? breakdownNotes,
    List<String>? breakdownPhotoPaths,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? dropoffLat,
    double? dropoffLng,
    String? dropoffAddress,
    double? geodesicDistanceKm,
    double? estimatedDistanceKm,
    int? estimatedDurationMin,
    double? baseFareSnapshot,
    double? pricePerKmSnapshot,
    double? estimatedPrice,
    double? finalPrice,
    String? currency,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    TripStatus? status,
    int? currentWave,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? acceptedAt,
    DateTime? enRouteAt,
    DateTime? arrivedAt,
    DateTime? loadedAt,
    DateTime? dropoffStartedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RescueRequest(
      id: id ?? this.id,
      requestCode: requestCode ?? this.requestCode,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      winchTypeId: winchTypeId ?? this.winchTypeId,
      winchId: winchId ?? this.winchId,
      customerVehicleId: customerVehicleId ?? this.customerVehicleId,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      breakdownReason: breakdownReason ?? this.breakdownReason,
      breakdownNotes: breakdownNotes ?? this.breakdownNotes,
      breakdownPhotoPaths: breakdownPhotoPaths ?? this.breakdownPhotoPaths,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      geodesicDistanceKm: geodesicDistanceKm ?? this.geodesicDistanceKm,
      estimatedDistanceKm: estimatedDistanceKm ?? this.estimatedDistanceKm,
      estimatedDurationMin: estimatedDurationMin ?? this.estimatedDurationMin,
      baseFareSnapshot: baseFareSnapshot ?? this.baseFareSnapshot,
      pricePerKmSnapshot: pricePerKmSnapshot ?? this.pricePerKmSnapshot,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      currentWave: currentWave ?? this.currentWave,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      enRouteAt: enRouteAt ?? this.enRouteAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      loadedAt: loadedAt ?? this.loadedAt,
      dropoffStartedAt: dropoffStartedAt ?? this.dropoffStartedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RescueRequest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestCode == other.requestCode &&
          customerId == other.customerId &&
          driverId == other.driverId &&
          winchTypeId == other.winchTypeId &&
          winchId == other.winchId &&
          customerVehicleId == other.customerVehicleId &&
          vehicleMake == other.vehicleMake &&
          vehicleModel == other.vehicleModel &&
          vehicleYear == other.vehicleYear &&
          vehicleColor == other.vehicleColor &&
          vehiclePlate == other.vehiclePlate &&
          vehicleCategory == other.vehicleCategory &&
          breakdownReason == other.breakdownReason &&
          breakdownNotes == other.breakdownNotes &&
          JsonParsers.stringListEquals(
            breakdownPhotoPaths,
            other.breakdownPhotoPaths,
          ) &&
          pickupLat == other.pickupLat &&
          pickupLng == other.pickupLng &&
          pickupAddress == other.pickupAddress &&
          dropoffLat == other.dropoffLat &&
          dropoffLng == other.dropoffLng &&
          dropoffAddress == other.dropoffAddress &&
          geodesicDistanceKm == other.geodesicDistanceKm &&
          estimatedDistanceKm == other.estimatedDistanceKm &&
          estimatedDurationMin == other.estimatedDurationMin &&
          baseFareSnapshot == other.baseFareSnapshot &&
          pricePerKmSnapshot == other.pricePerKmSnapshot &&
          estimatedPrice == other.estimatedPrice &&
          finalPrice == other.finalPrice &&
          currency == other.currency &&
          paymentMethod == other.paymentMethod &&
          paymentStatus == other.paymentStatus &&
          status == other.status &&
          currentWave == other.currentWave &&
          cancellationReason == other.cancellationReason &&
          cancelledBy == other.cancelledBy &&
          acceptedAt == other.acceptedAt &&
          enRouteAt == other.enRouteAt &&
          arrivedAt == other.arrivedAt &&
          loadedAt == other.loadedAt &&
          dropoffStartedAt == other.dropoffStartedAt &&
          completedAt == other.completedAt &&
          cancelledAt == other.cancelledAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        requestCode,
        customerId,
        driverId,
        winchTypeId,
        winchId,
        customerVehicleId,
        vehicleMake,
        vehicleModel,
        vehicleYear,
        vehicleColor,
        vehiclePlate,
        vehicleCategory,
        breakdownReason,
        breakdownNotes,
        Object.hashAll(breakdownPhotoPaths),
        pickupLat,
        pickupLng,
        pickupAddress,
        dropoffLat,
        dropoffLng,
        dropoffAddress,
        geodesicDistanceKm,
        estimatedDistanceKm,
        estimatedDurationMin,
        baseFareSnapshot,
        pricePerKmSnapshot,
        estimatedPrice,
        finalPrice,
        currency,
        paymentMethod,
        paymentStatus,
        status,
        currentWave,
        cancellationReason,
        cancelledBy,
        acceptedAt,
        enRouteAt,
        arrivedAt,
        loadedAt,
        dropoffStartedAt,
        completedAt,
        cancelledAt,
        createdAt,
        updatedAt,
      ]);
}

/// Summary returned by `public.dispatch_rescue_request` RPC (Migration 004).
@immutable
class DispatchResult {
  const DispatchResult({
    required this.requestId,
    this.waveNumber,
    this.radiusMeters,
    required this.dispatchedCount,
    this.expiresAt,
    this.status,
    this.message,
  });

  final String requestId;
  final int? waveNumber;
  final int? radiusMeters;
  final int dispatchedCount;
  final DateTime? expiresAt;
  final TripStatus? status;
  final String? message;

  factory DispatchResult.fromJson(Map<String, dynamic> json) {
    return DispatchResult(
      requestId: json['request_id'] as String,
      waveNumber: JsonParsers.asNullableInt(json['wave_number']),
      radiusMeters: JsonParsers.asNullableInt(json['radius_meters']),
      dispatchedCount:
          JsonParsers.asNullableInt(json['dispatched_count']) ?? 0,
      expiresAt: JsonParsers.asNullableDateTime(json['expires_at']),
      status: TripStatus.tryFromJson(json['status']),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'request_id': requestId,
      if (waveNumber != null) 'wave_number': waveNumber,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      'dispatched_count': dispatchedCount,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (status != null) 'status': status!.toJson(),
      if (message != null) 'message': message,
    };
  }
}

/// Composite JSONB payload returned by `public.create_rescue_request` RPC
/// (Migration 004).
@immutable
class CreateRescueRequestResult {
  const CreateRescueRequestResult({
    required this.request,
    required this.quote,
    required this.dispatch,
  });

  final RescueRequest request;
  final WinchQuote quote;
  final DispatchResult dispatch;

  factory CreateRescueRequestResult.fromJson(Map<String, dynamic> json) {
    return CreateRescueRequestResult(
      request: RescueRequest.fromJson(
        Map<String, dynamic>.from(json['request'] as Map),
      ),
      quote: WinchQuote.fromJson(
        Map<String, dynamic>.from(json['quote'] as Map),
      ),
      dispatch: DispatchResult.fromJson(
        Map<String, dynamic>.from(json['dispatch'] as Map),
      ),
    );
  }
}
