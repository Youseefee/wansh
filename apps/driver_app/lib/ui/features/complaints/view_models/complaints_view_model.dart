import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/driver_history_repository.dart';
import '../../../../data/services/media_picker_service.dart';
import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';

/// ViewModel managing driver support tickets (`complaints`) and evidence uploads
/// (`complaint-evidence`).
class ComplaintsViewModel extends ChangeNotifier {
  ComplaintsViewModel({
    required this._historyRepository,
    required this._sessionController,
    required this._mediaPicker,
    required this._localeController,
  });

  final DriverHistoryRepository _historyRepository;
  final DriverSessionController _sessionController;
  final DriverMediaPicker _mediaPicker;
  final LocaleController _localeController;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  List<Complaint> _complaints = const <Complaint>[];
  List<RescueRequest> _driverTrips = const <RescueRequest>[];
  final List<PickedMediaFile> _stagedEvidence = <PickedMediaFile>[];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  List<Complaint> get complaints => _complaints;
  List<RescueRequest> get driverTrips => _driverTrips;
  List<PickedMediaFile> get stagedEvidence =>
      List<PickedMediaFile>.unmodifiable(_stagedEvidence);

  Future<void> loadComplaints() async {
    final driverId = _sessionController.driverId;
    if (driverId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _historyRepository.getMyComplaints(driverId),
        _historyRepository.getDriverTrips(driverId),
      ]);
      _complaints = results[0] as List<Complaint>;
      _driverTrips = results[1] as List<RescueRequest>;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickEvidence({required ImageSource source}) async {
    try {
      if (source == ImageSource.gallery) {
        final files = await _mediaPicker.pickMultiImage();
        if (files.isNotEmpty) {
          _stagedEvidence.addAll(files);
          notifyListeners();
        }
      } else {
        final file = await _mediaPicker.pickImage(source: source);
        if (file != null) {
          _stagedEvidence.add(file);
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void stageEvidenceFile(PickedMediaFile file) {
    _stagedEvidence.add(file);
    notifyListeners();
  }

  void removeEvidenceAt(int index) {
    if (index < 0 || index >= _stagedEvidence.length) return;
    _stagedEvidence.removeAt(index);
    notifyListeners();
  }

  Future<bool> submitComplaint({
    required ComplaintCategory category,
    required String subject,
    required String description,
    RescueRequest? relatedTrip,
  }) async {
    final reporterId = _sessionController.driverId;
    if (reporterId == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final created = await _historyRepository.submitComplaint(
        reporterId: reporterId,
        requestId: relatedTrip?.id,
        reportedUserId: relatedTrip?.customerId,
        category: category,
        subject: subject,
        description: description,
        evidenceFiles: List<PickedMediaFile>.from(_stagedEvidence),
      );
      _complaints = <Complaint>[created, ..._complaints];
      _stagedEvidence.clear();
      _successMessage = DriverStrings.t(
        _localeController.localeCode,
        'تم إرسال الشكوى بنجاح برقم ${created.complaintCode}.',
        'Complaint submitted (${created.complaintCode}).',
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
}
