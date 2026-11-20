import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';
import 'rescue_request.dart';

/// Candidate dispatch invitation matching `public.dispatch_offers`
/// (Migration 002).
@immutable
class DispatchOffer {
  const DispatchOffer({
    required this.id,
    required this.requestId,
    required this.driverId,
    required this.winchId,
    required this.distanceMeters,
    this.etaMinutes,
    this.waveNumber = 1,
    this.status = OfferStatus.pending,
    this.rejectionReason,
    required this.expiresAt,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
    this.rescueRequest,
  });

  final String id;
  final String requestId;
  final String driverId;
  final String winchId;
  final int distanceMeters;
  final int? etaMinutes;
  final int waveNumber;
  final OfferStatus status;
  final String? rejectionReason;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional joined `rescue_requests` record when selected with a join.
  final RescueRequest? rescueRequest;

  /// Whether the offer's TTL has elapsed relative to [now] (UTC).
  bool isExpiredAt([DateTime? now]) {
    final reference = (now ?? DateTime.now()).toUtc();
    return !expiresAt.toUtc().isAfter(reference);
  }

  /// Remaining time before expiry (clamped at [Duration.zero]).
  Duration remainingTime([DateTime? now]) {
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = expiresAt.toUtc().difference(reference);
    return diff.isNegative ? Duration.zero : diff;
  }

  factory DispatchOffer.fromJson(Map<String, dynamic> json) {
    final nestedReq = json['rescue_requests'];
    return DispatchOffer(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      driverId: json['driver_id'] as String,
      winchId: json['winch_id'] as String,
      distanceMeters: JsonParsers.asInt(
        json['distance_meters'],
        field: 'distance_meters',
      ),
      etaMinutes: JsonParsers.asNullableInt(json['eta_minutes']),
      waveNumber: JsonParsers.asNullableInt(json['wave_number']) ?? 1,
      status: OfferStatus.tryFromJson(json['status']) ?? OfferStatus.pending,
      rejectionReason: json['rejection_reason'] as String?,
      expiresAt: JsonParsers.asDateTime(
        json['expires_at'],
        field: 'expires_at',
      ),
      respondedAt: JsonParsers.asNullableDateTime(json['responded_at']),
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
      updatedAt: JsonParsers.asDateTime(
        json['updated_at'],
        field: 'updated_at',
      ),
      rescueRequest: nestedReq is Map<String, dynamic>
          ? RescueRequest.fromJson(nestedReq)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'request_id': requestId,
      'driver_id': driverId,
      'winch_id': winchId,
      'distance_meters': distanceMeters,
      'eta_minutes': etaMinutes,
      'wave_number': waveNumber,
      'status': status.toJson(),
      'rejection_reason': rejectionReason,
      'expires_at': expiresAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DispatchOffer copyWith({
    String? id,
    String? requestId,
    String? driverId,
    String? winchId,
    int? distanceMeters,
    int? etaMinutes,
    int? waveNumber,
    OfferStatus? status,
    String? rejectionReason,
    DateTime? expiresAt,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    RescueRequest? rescueRequest,
  }) {
    return DispatchOffer(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      driverId: driverId ?? this.driverId,
      winchId: winchId ?? this.winchId,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      waveNumber: waveNumber ?? this.waveNumber,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      expiresAt: expiresAt ?? this.expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rescueRequest: rescueRequest ?? this.rescueRequest,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DispatchOffer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestId == other.requestId &&
          driverId == other.driverId &&
          winchId == other.winchId &&
          distanceMeters == other.distanceMeters &&
          etaMinutes == other.etaMinutes &&
          waveNumber == other.waveNumber &&
          status == other.status &&
          rejectionReason == other.rejectionReason &&
          expiresAt == other.expiresAt &&
          respondedAt == other.respondedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          rescueRequest == other.rescueRequest;

  @override
  int get hashCode => Object.hash(
        id,
        requestId,
        driverId,
        winchId,
        distanceMeters,
        etaMinutes,
        waveNumber,
        status,
        rejectionReason,
        expiresAt,
        respondedAt,
        createdAt,
        updatedAt,
        rescueRequest,
      );
}
