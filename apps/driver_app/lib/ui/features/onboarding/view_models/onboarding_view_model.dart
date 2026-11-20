import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/driver_onboarding_repository.dart';
import '../../../../data/services/media_picker_service.dart';
import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';

/// ViewModel managing tow-truck setup (`driver_winches`), KYC compliance uploads
/// (`driver_documents`), and the Approval Gate status refresh.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required this._onboardingRepository,
    required this._sessionController,
    required this._mediaPicker,
    required this._localeController,
  });

  final DriverOnboardingRepository _onboardingRepository;
  final DriverSessionController _sessionController;
  final DriverMediaPicker _mediaPicker;
  final LocaleController _localeController;

  bool _isLoading = false;
  bool _isSubmitting = false;
  DocumentType? _uploadingDocType;
  String? _errorMessage;
  String? _successMessage;

  List<WinchType> _winchTypes = const <WinchType>[];
  List<DriverWinch> _winches = const <DriverWinch>[];
  List<DriverDocument> _documents = const <DriverDocument>[];
  final List<PickedMediaFile> _stagedWinchPhotos = <PickedMediaFile>[];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  DocumentType? get uploadingDocType => _uploadingDocType;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  List<WinchType> get winchTypes => _winchTypes;
  List<DriverWinch> get winches => _winches;
  List<DriverDocument> get documents => _documents;
  List<PickedMediaFile> get stagedWinchPhotos =>
      List<PickedMediaFile>.unmodifiable(_stagedWinchPhotos);

  DriverProfile? get driverProfile => _sessionController.driverProfile;

  /// Required baseline KYC documents for initial review.
  static const List<DocumentType> requiredDocuments = <DocumentType>[
    DocumentType.nationalIdFront,
    DocumentType.nationalIdBack,
    DocumentType.driverLicenseFront,
    DocumentType.driverLicenseBack,
    DocumentType.winchLicenseFront,
    DocumentType.winchLicenseBack,
    DocumentType.criminalRecord,
    DocumentType.selfieWithId,
  ];

  DriverDocument? documentForType(DocumentType type) {
    for (final doc in _documents) {
      if (doc.documentType == type) return doc;
    }
    return null;
  }

  int get uploadedDocumentsCount => requiredDocuments
      .where((type) => documentForType(type) != null)
      .length;

  int get rejectedDocumentsCount => _documents
      .where((doc) => doc.reviewStatus == DocumentReviewStatus.rejected)
      .length;

  bool get hasRegisteredWinch => _winches.isNotEmpty;

  String winchPhotoUrl(String storagePath) =>
      _onboardingRepository.getWinchPhotoPublicUrl(storagePath);

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) return;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> loadOnboardingData({bool refreshSession = false}) async {
    final driverId = _sessionController.driverId;
    if (driverId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (refreshSession) {
        await _sessionController.refreshSession();
      }
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _onboardingRepository.getWinchTypes(),
        _onboardingRepository.getMyWinches(driverId),
        _onboardingRepository.getMyDocuments(driverId),
      ]);
      _winchTypes = results[0] as List<WinchType>;
      _winches = results[1] as List<DriverWinch>;
      _documents = results[2] as List<DriverDocument>;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickWinchPhoto({required ImageSource source}) async {
    try {
      if (source == ImageSource.gallery) {
        final picked = await _mediaPicker.pickMultiImage();
        if (picked.isNotEmpty) {
          _stagedWinchPhotos.addAll(picked);
          notifyListeners();
        }
      } else {
        final picked = await _mediaPicker.pickImage(source: source);
        if (picked != null) {
          _stagedWinchPhotos.add(picked);
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void removeStagedWinchPhoto(int index) {
    if (index < 0 || index >= _stagedWinchPhotos.length) return;
    _stagedWinchPhotos.removeAt(index);
    notifyListeners();
  }

  Future<bool> registerWinch({
    required String winchTypeId,
    required String plateNumber,
    required String brand,
    required String model,
    int? year,
    String? color,
    double? maxCapacityTons,
    String? winchLicenseNumber,
    DateTime? winchLicenseExpiry,
  }) async {
    final driverId = _sessionController.driverId;
    if (driverId == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final created = await _onboardingRepository.registerWinch(
        driverId: driverId,
        winchTypeId: winchTypeId,
        plateNumber: plateNumber,
        brand: brand,
        model: model,
        year: year,
        color: color,
        maxCapacityTons: maxCapacityTons,
        winchLicenseNumber: winchLicenseNumber,
        winchLicenseExpiry: winchLicenseExpiry,
        photos: List<PickedMediaFile>.from(_stagedWinchPhotos),
      );
      _winches = <DriverWinch>[created, ..._winches];
      _stagedWinchPhotos.clear();
      _successMessage = DriverStrings.t(
        _localeController.localeCode,
        'تم تسجيل الونش بنجاح.',
        'Tow truck registered successfully.',
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> pickAndUploadDocument({
    required DocumentType documentType,
    required ImageSource source,
    DateTime? expiresAt,
  }) async {
    final driverId = _sessionController.driverId;
    if (driverId == null) return false;

    _errorMessage = null;
    _successMessage = null;

    PickedMediaFile? file;
    try {
      file = await _mediaPicker.pickImage(source: source);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
    if (file == null) return false;

    return uploadDocumentBytes(
      documentType: documentType,
      file: file,
      expiresAt: expiresAt,
    );
  }

  Future<bool> uploadDocumentBytes({
    required DocumentType documentType,
    required PickedMediaFile file,
    DateTime? expiresAt,
  }) async {
    final driverId = _sessionController.driverId;
    if (driverId == null) return false;

    _uploadingDocType = documentType;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final primaryWinchId = _winches.isNotEmpty ? _winches.first.id : null;
      final isWinchDoc = documentType == DocumentType.winchLicenseFront ||
          documentType == DocumentType.winchLicenseBack;

      final upserted = await _onboardingRepository.uploadKycDocument(
        driverId: driverId,
        documentType: documentType,
        file: file,
        winchId: isWinchDoc ? primaryWinchId : null,
        expiresAt: expiresAt,
      );

      final updatedList = List<DriverDocument>.from(_documents)
        ..removeWhere((d) => d.documentType == documentType)
        ..add(upserted);
      _documents = updatedList;
      _successMessage = DriverStrings.t(
        _localeController.localeCode,
        'تم رفع المستند وإرساله للمراجعة.',
        'Document uploaded and queued for review.',
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _uploadingDocType = null;
      notifyListeners();
    }
  }

  Future<String?> fetchDocumentSignedUrl(DriverDocument doc) async {
    try {
      return await _onboardingRepository.getDocumentSignedUrl(doc.storagePath);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
