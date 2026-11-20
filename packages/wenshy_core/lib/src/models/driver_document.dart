import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';

/// Driver KYC / compliance document matching `public.driver_documents`
/// (Migration 002).
@immutable
class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.driverId,
    this.winchId,
    required this.documentType,
    required this.storagePath,
    this.reviewStatus = DocumentReviewStatus.pending,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String driverId;
  final String? winchId;
  final DocumentType documentType;
  final String storagePath;
  final DocumentReviewStatus reviewStatus;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      winchId: json['winch_id'] as String?,
      documentType: DocumentType.fromJson(json['document_type']),
      storagePath: json['storage_path'] as String,
      reviewStatus:
          DocumentReviewStatus.tryFromJson(json['review_status']) ??
              DocumentReviewStatus.pending,
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: JsonParsers.asNullableDateTime(json['reviewed_at']),
      expiresAt: JsonParsers.asNullableDateTime(json['expires_at']),
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
      'driver_id': driverId,
      'winch_id': winchId,
      'document_type': documentType.toJson(),
      'storage_path': storagePath,
      'review_status': reviewStatus.toJson(),
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'expires_at': JsonParsers.toSqlDate(expiresAt),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Payload suitable for upserting into `public.driver_documents` on
  /// `(driver_id, document_type)`.
  Map<String, dynamic> toUpsertJson() {
    return <String, dynamic>{
      'driver_id': driverId,
      if (winchId != null) 'winch_id': winchId,
      'document_type': documentType.toJson(),
      'storage_path': storagePath,
      if (expiresAt != null) 'expires_at': JsonParsers.toSqlDate(expiresAt),
    };
  }

  DriverDocument copyWith({
    String? id,
    String? driverId,
    String? winchId,
    DocumentType? documentType,
    String? storagePath,
    DocumentReviewStatus? reviewStatus,
    String? rejectionReason,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverDocument(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      winchId: winchId ?? this.winchId,
      documentType: documentType ?? this.documentType,
      storagePath: storagePath ?? this.storagePath,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          driverId == other.driverId &&
          winchId == other.winchId &&
          documentType == other.documentType &&
          storagePath == other.storagePath &&
          reviewStatus == other.reviewStatus &&
          rejectionReason == other.rejectionReason &&
          reviewedBy == other.reviewedBy &&
          reviewedAt == other.reviewedAt &&
          expiresAt == other.expiresAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        driverId,
        winchId,
        documentType,
        storagePath,
        reviewStatus,
        rejectionReason,
        reviewedBy,
        reviewedAt,
        expiresAt,
        createdAt,
        updatedAt,
      );
}
