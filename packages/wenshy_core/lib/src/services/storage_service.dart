import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/enums.dart';

/// Shared Supabase Storage helper supporting upsert uploads, signed URLs for
/// private buckets, and public URLs for `winch-photos`.
class StorageService {
  const StorageService({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Uploads raw [bytes] to [bucket] at [path] and returns the relative
  /// object [path] (without the `<bucket>/` prefix) for storing in DB columns.
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) async {
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    await _supabase.storage.from(bucket).uploadBinary(
          normalizedPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: upsert,
          ),
        );
    return normalizedPath;
  }

  /// Uploads a driver KYC document to `driver-documents` at
  /// `<driver_id>/<doc_type>/<file_name>`.
  Future<String> uploadDriverDocument({
    required String driverId,
    required DocumentType documentType,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) {
    final path = StorageBuckets.driverDocumentPath(
      driverId: driverId,
      documentType: documentType,
      fileName: fileName,
    );
    return uploadBytes(
      bucket: StorageBuckets.driverDocuments,
      path: path,
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    );
  }

  /// Uploads a tow-truck photo to `winch-photos` at `<driver_id>/<file_name>`.
  Future<String> uploadWinchPhoto({
    required String driverId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) {
    final path = StorageBuckets.winchPhotoPath(
      driverId: driverId,
      fileName: fileName,
    );
    return uploadBytes(
      bucket: StorageBuckets.winchPhotos,
      path: path,
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    );
  }

  /// Uploads a vehicle breakdown photo to `breakdown-photos` at
  /// `<customer_id>/<request_id>/<file_name>`.
  Future<String> uploadBreakdownPhoto({
    required String customerId,
    required String requestId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) {
    final path = StorageBuckets.breakdownPhotoPath(
      customerId: customerId,
      requestId: requestId,
      fileName: fileName,
    );
    return uploadBytes(
      bucket: StorageBuckets.breakdownPhotos,
      path: path,
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    );
  }

  /// Uploads complaint evidence to `complaint-evidence` at
  /// `<reporter_id>/<file_name>`.
  Future<String> uploadComplaintEvidence({
    required String reporterId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    bool upsert = true,
  }) {
    final path = StorageBuckets.complaintEvidencePath(
      reporterId: reporterId,
      fileName: fileName,
    );
    return uploadBytes(
      bucket: StorageBuckets.complaintEvidence,
      path: path,
      bytes: bytes,
      contentType: contentType,
      upsert: upsert,
    );
  }

  /// Creates a temporary signed download URL for a private bucket object.
  Future<String> createSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) {
    return _supabase.storage
        .from(bucket)
        .createSignedUrl(path, expiresInSeconds);
  }

  /// Creates temporary signed URLs for multiple objects, returning a map of
  /// `{path: signedUrl}` for objects that succeeded.
  Future<Map<String, String>> createSignedUrls({
    required String bucket,
    required List<String> paths,
    int expiresInSeconds = 3600,
  }) async {
    if (paths.isEmpty) return const <String, String>{};
    final results = await _supabase.storage
        .from(bucket)
        .createSignedUrlsResult(paths, expiresInSeconds);

    final signedMap = <String, String>{};
    for (final result in results) {
      if (result is SignedUrlSuccess) {
        signedMap[result.path] = result.signedUrl;
      }
    }
    return signedMap;
  }

  /// Returns the public URL for an object in a public bucket (such as
  /// [StorageBuckets.winchPhotos]).
  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  /// Deletes one or more objects from [bucket].
  Future<List<FileObject>> removeFiles({
    required String bucket,
    required List<String> paths,
  }) {
    if (paths.isEmpty) return Future<List<FileObject>>.value(const []);
    return _supabase.storage.from(bucket).remove(paths);
  }
}
