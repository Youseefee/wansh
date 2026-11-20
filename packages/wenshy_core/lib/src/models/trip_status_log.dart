import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';

/// Immutable audit trail entry matching `public.trip_status_logs`
/// (Migration 002).
@immutable
class TripStatusLog {
  const TripStatusLog({
    required this.id,
    required this.requestId,
    this.fromStatus,
    required this.toStatus,
    this.changedBy,
    this.lat,
    this.lng,
    this.notes,
    required this.createdAt,
  });

  final int id;
  final String requestId;
  final TripStatus? fromStatus;
  final TripStatus toStatus;
  final String? changedBy;
  final double? lat;
  final double? lng;
  final String? notes;
  final DateTime createdAt;

  factory TripStatusLog.fromJson(Map<String, dynamic> json) {
    return TripStatusLog(
      id: JsonParsers.asInt(json['id'], field: 'id'),
      requestId: json['request_id'] as String,
      fromStatus: TripStatus.tryFromJson(json['from_status']),
      toStatus: TripStatus.fromJson(json['to_status']),
      changedBy: json['changed_by'] as String?,
      lat: JsonParsers.asNullableDouble(json['lat']),
      lng: JsonParsers.asNullableDouble(json['lng']),
      notes: json['notes'] as String?,
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'request_id': requestId,
      'from_status': fromStatus?.toJson(),
      'to_status': toStatus.toJson(),
      'changed_by': changedBy,
      'lat': lat,
      'lng': lng,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TripStatusLog copyWith({
    int? id,
    String? requestId,
    TripStatus? fromStatus,
    TripStatus? toStatus,
    String? changedBy,
    double? lat,
    double? lng,
    String? notes,
    DateTime? createdAt,
  }) {
    return TripStatusLog(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      changedBy: changedBy ?? this.changedBy,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripStatusLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestId == other.requestId &&
          fromStatus == other.fromStatus &&
          toStatus == other.toStatus &&
          changedBy == other.changedBy &&
          lat == other.lat &&
          lng == other.lng &&
          notes == other.notes &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        requestId,
        fromStatus,
        toStatus,
        changedBy,
        lat,
        lng,
        notes,
        createdAt,
      );
}
