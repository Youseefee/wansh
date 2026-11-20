import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';

/// Dispute / support ticket matching `public.complaints` (Migration 002).
@immutable
class Complaint {
  const Complaint({
    required this.id,
    required this.complaintCode,
    this.requestId,
    required this.reporterId,
    this.reportedUserId,
    required this.category,
    required this.subject,
    required this.description,
    this.evidencePaths = const <String>[],
    this.status = ComplaintStatus.open,
    this.adminNotes,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String complaintCode;
  final String? requestId;
  final String reporterId;
  final String? reportedUserId;
  final ComplaintCategory category;
  final String subject;
  final String description;
  final List<String> evidencePaths;
  final ComplaintStatus status;
  final String? adminNotes;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String,
      complaintCode: json['complaint_code'] as String,
      requestId: json['request_id'] as String?,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String?,
      category: ComplaintCategory.fromJson(json['category']),
      subject: json['subject'] as String,
      description: json['description'] as String,
      evidencePaths: JsonParsers.asStringList(json['evidence_paths']),
      status: ComplaintStatus.tryFromJson(json['status']) ??
          ComplaintStatus.open,
      adminNotes: json['admin_notes'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: JsonParsers.asNullableDateTime(json['resolved_at']),
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
      'complaint_code': complaintCode,
      'request_id': requestId,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'category': category.toJson(),
      'subject': subject,
      'description': description,
      'evidence_paths': evidencePaths,
      'status': status.toJson(),
      'admin_notes': adminNotes,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Payload suitable for inserting a new ticket into `public.complaints`.
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      if (requestId != null) 'request_id': requestId,
      'reporter_id': reporterId,
      if (reportedUserId != null) 'reported_user_id': reportedUserId,
      'category': category.toJson(),
      'subject': subject,
      'description': description,
      'evidence_paths': evidencePaths,
    };
  }

  Complaint copyWith({
    String? id,
    String? complaintCode,
    String? requestId,
    String? reporterId,
    String? reportedUserId,
    ComplaintCategory? category,
    String? subject,
    String? description,
    List<String>? evidencePaths,
    ComplaintStatus? status,
    String? adminNotes,
    String? resolvedBy,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Complaint(
      id: id ?? this.id,
      complaintCode: complaintCode ?? this.complaintCode,
      requestId: requestId ?? this.requestId,
      reporterId: reporterId ?? this.reporterId,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      evidencePaths: evidencePaths ?? this.evidencePaths,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Complaint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          complaintCode == other.complaintCode &&
          requestId == other.requestId &&
          reporterId == other.reporterId &&
          reportedUserId == other.reportedUserId &&
          category == other.category &&
          subject == other.subject &&
          description == other.description &&
          JsonParsers.stringListEquals(evidencePaths, other.evidencePaths) &&
          status == other.status &&
          adminNotes == other.adminNotes &&
          resolvedBy == other.resolvedBy &&
          resolvedAt == other.resolvedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        complaintCode,
        requestId,
        reporterId,
        reportedUserId,
        category,
        subject,
        description,
        Object.hashAll(evidencePaths),
        status,
        adminNotes,
        resolvedBy,
        resolvedAt,
        createdAt,
        updatedAt,
      );
}
