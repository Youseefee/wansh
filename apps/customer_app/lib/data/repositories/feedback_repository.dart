import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'models.dart';

/// Repository for trip ratings (`public.ratings`) and customer complaints
/// (`public.complaints` + `complaint-evidence` bucket).
abstract class FeedbackRepository {
  Future<TripRating?> getRatingForRequest(String requestId);

  Future<TripRating> submitRating({
    required String requestId,
    required String customerId,
    required String driverId,
    required int score,
    String? comment,
    List<String> tags = const <String>[],
  });

  Future<List<Complaint>> getMyComplaints(String reporterId);

  Future<Complaint> submitComplaint({
    required String reporterId,
    String? requestId,
    String? reportedUserId,
    required ComplaintCategory category,
    required String subject,
    required String description,
    List<SelectedPhotoBytes> evidenceFiles = const <SelectedPhotoBytes>[],
  });

  Future<Map<String, String>> getComplaintEvidenceSignedUrls(
    List<String> paths,
  );
}

/// Supabase implementation of [FeedbackRepository].
class SupabaseFeedbackRepository implements FeedbackRepository {
  SupabaseFeedbackRepository({
    SupabaseClient? client,
    StorageService? storageService,
  })  : _client = client,
        _storage = storageService ?? StorageService(client: client);

  final SupabaseClient? _client;
  final StorageService _storage;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<TripRating?> getRatingForRequest(String requestId) async {
    final row = await _supabase
        .from(WenshyTables.ratings)
        .select()
        .eq('request_id', requestId)
        .maybeSingle();

    if (row == null) return null;
    return TripRating.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<TripRating> submitRating({
    required String requestId,
    required String customerId,
    required String driverId,
    required int score,
    String? comment,
    List<String> tags = const <String>[],
  }) async {
    final draft = TripRating(
      id: '',
      requestId: requestId,
      customerId: customerId,
      driverId: driverId,
      score: score,
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      tags: tags,
      createdAt: DateTime.now().toUtc(),
    );

    final row = await _supabase
        .from(WenshyTables.ratings)
        .insert(draft.toInsertJson())
        .select()
        .single();

    return TripRating.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Complaint>> getMyComplaints(String reporterId) async {
    final rows = await _supabase
        .from(WenshyTables.complaints)
        .select()
        .eq('reporter_id', reporterId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Complaint.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<Complaint> submitComplaint({
    required String reporterId,
    String? requestId,
    String? reportedUserId,
    required ComplaintCategory category,
    required String subject,
    required String description,
    List<SelectedPhotoBytes> evidenceFiles = const <SelectedPhotoBytes>[],
  }) async {
    final evidencePaths = <String>[];
    for (var i = 0; i < evidenceFiles.length; i++) {
      final file = evidenceFiles[i];
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_${i}_${file.fileName}';
      final path = await _storage.uploadComplaintEvidence(
        reporterId: reporterId,
        fileName: safeName,
        bytes: file.bytes,
        contentType: file.contentType,
      );
      evidencePaths.add(path);
    }

    final now = DateTime.now().toUtc();
    final draft = Complaint(
      id: '',
      complaintCode: '',
      requestId: requestId,
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      category: category,
      subject: subject.trim(),
      description: description.trim(),
      evidencePaths: evidencePaths,
      createdAt: now,
      updatedAt: now,
    );

    final row = await _supabase
        .from(WenshyTables.complaints)
        .insert(draft.toInsertJson())
        .select()
        .single();

    return Complaint.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<Map<String, String>> getComplaintEvidenceSignedUrls(
    List<String> paths,
  ) {
    return _storage.createSignedUrls(
      bucket: StorageBuckets.complaintEvidence,
      paths: paths,
    );
  }
}
