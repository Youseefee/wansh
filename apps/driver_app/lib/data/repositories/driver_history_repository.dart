import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../services/media_picker_service.dart';

/// Repository for driver trip history, ratings, and support complaints.
abstract class DriverHistoryRepository {
  Future<List<RescueRequest>> getDriverTrips(String driverId);
  Future<List<TripRating>> getDriverRatings(String driverId);
  Future<List<Complaint>> getMyComplaints(String reporterId);

  Future<Complaint> submitComplaint({
    required String reporterId,
    String? requestId,
    String? reportedUserId,
    required ComplaintCategory category,
    required String subject,
    required String description,
    List<PickedMediaFile> evidenceFiles = const <PickedMediaFile>[],
  });
}

/// Supabase-backed implementation of [DriverHistoryRepository].
class SupabaseDriverHistoryRepository implements DriverHistoryRepository {
  SupabaseDriverHistoryRepository({
    SupabaseClient? client,
    StorageService? storageService,
  })  : _supabase = client ?? Supabase.instance.client,
        _storageService = storageService ?? StorageService(client: client);

  final SupabaseClient _supabase;
  final StorageService _storageService;

  @override
  Future<List<RescueRequest>> getDriverTrips(String driverId) async {
    final rows = await _supabase
        .from(WenshyTables.rescueRequests)
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) =>
              RescueRequest.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TripRating>> getDriverRatings(String driverId) async {
    final rows = await _supabase
        .from(WenshyTables.ratings)
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => TripRating.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Complaint>> getMyComplaints(String reporterId) async {
    final rows = await _supabase
        .from(WenshyTables.complaints)
        .select()
        .eq('reporter_id', reporterId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => Complaint.fromJson(Map<String, dynamic>.from(row as Map)),
        )
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
    List<PickedMediaFile> evidenceFiles = const <PickedMediaFile>[],
  }) async {
    final evidencePaths = <String>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < evidenceFiles.length; i++) {
      final file = evidenceFiles[i];
      final path = await _storageService.uploadComplaintEvidence(
        reporterId: reporterId,
        fileName: 'evidence_${stamp}_$i.${file.extension}',
        bytes: file.bytes,
        contentType: file.contentType,
        upsert: true,
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

    final inserted = await _supabase
        .from(WenshyTables.complaints)
        .insert(draft.toInsertJson())
        .select()
        .single();

    return Complaint.fromJson(Map<String, dynamic>.from(inserted));
  }
}
