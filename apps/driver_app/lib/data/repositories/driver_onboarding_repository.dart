import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../services/media_picker_service.dart';

/// Repository for tow-truck registration (`driver_winches`), winch photos
/// (`winch-photos`), and KYC documents (`driver-documents` + `driver_documents`).
abstract class DriverOnboardingRepository {
  Future<List<WinchType>> getWinchTypes();
  Future<List<DriverWinch>> getMyWinches(String driverId);

  Future<DriverWinch> registerWinch({
    required String driverId,
    required String winchTypeId,
    required String plateNumber,
    required String brand,
    required String model,
    int? year,
    String? color,
    double? maxCapacityTons,
    String? winchLicenseNumber,
    DateTime? winchLicenseExpiry,
    List<PickedMediaFile> photos = const <PickedMediaFile>[],
  });

  Future<DriverWinch> addWinchPhotos({
    required String driverId,
    required DriverWinch winch,
    required List<PickedMediaFile> newPhotos,
  });

  Future<List<DriverDocument>> getMyDocuments(String driverId);

  Future<DriverDocument> uploadKycDocument({
    required String driverId,
    required DocumentType documentType,
    required PickedMediaFile file,
    String? winchId,
    DateTime? expiresAt,
  });

  Future<String> getDocumentSignedUrl(String storagePath);
  String getWinchPhotoPublicUrl(String storagePath);
}

/// Supabase-backed implementation of [DriverOnboardingRepository].
class SupabaseDriverOnboardingRepository implements DriverOnboardingRepository {
  SupabaseDriverOnboardingRepository({
    SupabaseClient? client,
    WinchCatalogService? catalogService,
    StorageService? storageService,
  })  : _supabase = client ?? Supabase.instance.client,
        _catalogService = catalogService ?? WinchCatalogService(client: client),
        _storageService = storageService ?? StorageService(client: client);

  final SupabaseClient _supabase;
  final WinchCatalogService _catalogService;
  final StorageService _storageService;

  @override
  Future<List<WinchType>> getWinchTypes() {
    return _catalogService.getActiveWinchTypes();
  }

  @override
  Future<List<DriverWinch>> getMyWinches(String driverId) async {
    final rows = await _supabase
        .from(WenshyTables.driverWinches)
        .select('*, winch_types(*)')
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => DriverWinch.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<List<String>> _uploadWinchPhotos(
    String driverId,
    List<PickedMediaFile> photos,
  ) async {
    final paths = <String>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final fileName = 'winch_${stamp}_$i.${photo.extension}';
      final path = await _storageService.uploadWinchPhoto(
        driverId: driverId,
        fileName: fileName,
        bytes: photo.bytes,
        contentType: photo.contentType,
        upsert: true,
      );
      paths.add(path);
    }
    return paths;
  }

  @override
  Future<DriverWinch> registerWinch({
    required String driverId,
    required String winchTypeId,
    required String plateNumber,
    required String brand,
    required String model,
    int? year,
    String? color,
    double? maxCapacityTons,
    String? winchLicenseNumber,
    DateTime? winchLicenseExpiry,
    List<PickedMediaFile> photos = const <PickedMediaFile>[],
  }) async {
    final uploadedPaths = await _uploadWinchPhotos(driverId, photos);

    final now = DateTime.now().toUtc();
    final draft = DriverWinch(
      id: '',
      driverId: driverId,
      winchTypeId: winchTypeId,
      plateNumber: plateNumber.trim(),
      brand: brand.trim(),
      model: model.trim(),
      year: year,
      color: color?.trim().isEmpty == true ? null : color?.trim(),
      maxCapacityTons: maxCapacityTons,
      winchLicenseNumber: winchLicenseNumber?.trim().isEmpty == true
          ? null
          : winchLicenseNumber?.trim(),
      winchLicenseExpiry: winchLicenseExpiry,
      photoPaths: uploadedPaths,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final inserted = await _supabase
        .from(WenshyTables.driverWinches)
        .insert(draft.toInsertJson())
        .select('*, winch_types(*)')
        .single();

    return DriverWinch.fromJson(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<DriverWinch> addWinchPhotos({
    required String driverId,
    required DriverWinch winch,
    required List<PickedMediaFile> newPhotos,
  }) async {
    if (newPhotos.isEmpty) return winch;
    final uploaded = await _uploadWinchPhotos(driverId, newPhotos);
    final merged = <String>[...winch.photoPaths, ...uploaded];

    final updated = await _supabase
        .from(WenshyTables.driverWinches)
        .update(<String, dynamic>{'photo_paths': merged})
        .eq('id', winch.id)
        .eq('driver_id', driverId)
        .select('*, winch_types(*)')
        .single();

    return DriverWinch.fromJson(Map<String, dynamic>.from(updated));
  }

  @override
  Future<List<DriverDocument>> getMyDocuments(String driverId) async {
    final rows = await _supabase
        .from(WenshyTables.driverDocuments)
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map(
          (row) =>
              DriverDocument.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<DriverDocument> uploadKycDocument({
    required String driverId,
    required DocumentType documentType,
    required PickedMediaFile file,
    String? winchId,
    DateTime? expiresAt,
  }) async {
    // Timestamped filename guarantees a new `storage_path` on re-upload so
    // Postgres trigger `trg_driver_documents_guard_mutations` resets
    // `review_status` back to `pending` when replacing a rejected document.
    final fileName =
        '${documentType.value}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}';

    final storagePath = await _storageService.uploadDriverDocument(
      driverId: driverId,
      documentType: documentType,
      fileName: fileName,
      bytes: file.bytes,
      contentType: file.contentType,
      upsert: true,
    );

    final now = DateTime.now().toUtc();
    final draft = DriverDocument(
      id: '',
      driverId: driverId,
      winchId: winchId,
      documentType: documentType,
      storagePath: storagePath,
      expiresAt: expiresAt,
      createdAt: now,
      updatedAt: now,
    );

    final upserted = await _supabase
        .from(WenshyTables.driverDocuments)
        .upsert(
          draft.toUpsertJson(),
          onConflict: 'driver_id,document_type',
        )
        .select()
        .single();

    return DriverDocument.fromJson(Map<String, dynamic>.from(upserted));
  }

  @override
  Future<String> getDocumentSignedUrl(String storagePath) {
    return _storageService.createSignedUrl(
      bucket: StorageBuckets.driverDocuments,
      path: storagePath,
    );
  }

  @override
  String getWinchPhotoPublicUrl(String storagePath) {
    return _storageService.getPublicUrl(
      bucket: StorageBuckets.winchPhotos,
      path: storagePath,
    );
  }
}
