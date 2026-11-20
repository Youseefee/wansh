import 'package:flutter/foundation.dart';

import 'json_parsers.dart';

/// Post-delivery customer rating matching `public.ratings` (Migration 002).
@immutable
class TripRating {
  const TripRating({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.driverId,
    required this.score,
    this.comment,
    this.tags = const <String>[],
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String customerId;
  final String driverId;
  final int score;
  final String? comment;
  final List<String> tags;
  final DateTime createdAt;

  factory TripRating.fromJson(Map<String, dynamic> json) {
    return TripRating(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String,
      score: JsonParsers.asInt(json['score'], field: 'score'),
      comment: json['comment'] as String?,
      tags: JsonParsers.asStringList(json['tags']),
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
      'customer_id': customerId,
      'driver_id': driverId,
      'score': score,
      'comment': comment,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Payload suitable for inserting into `public.ratings`.
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'request_id': requestId,
      'customer_id': customerId,
      'driver_id': driverId,
      'score': score,
      if (comment != null && comment!.trim().isNotEmpty) 'comment': comment,
      'tags': tags,
    };
  }

  TripRating copyWith({
    String? id,
    String? requestId,
    String? customerId,
    String? driverId,
    int? score,
    String? comment,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return TripRating(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripRating &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestId == other.requestId &&
          customerId == other.customerId &&
          driverId == other.driverId &&
          score == other.score &&
          comment == other.comment &&
          JsonParsers.stringListEquals(tags, other.tags) &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        requestId,
        customerId,
        driverId,
        score,
        comment,
        Object.hashAll(tags),
        createdAt,
      );
}
