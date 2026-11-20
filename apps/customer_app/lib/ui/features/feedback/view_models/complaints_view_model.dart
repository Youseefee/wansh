import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/feedback_repository.dart';
import '../../../../data/repositories/models.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for viewing and filing customer complaints (`public.complaints` +
/// `complaint-evidence` Storage bucket).
class ComplaintsViewModel extends ChangeNotifier {
  ComplaintsViewModel({required this._repository});

  final FeedbackRepository _repository;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<Complaint> _complaints = const <Complaint>[];
  ComplaintCategory _category = ComplaintCategory.delay;
  final List<SelectedPhotoBytes> _evidenceFiles = <SelectedPhotoBytes>[];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<Complaint> get complaints => _complaints;
  ComplaintCategory get category => _category;
  List<SelectedPhotoBytes> get evidenceFiles =>
      List.unmodifiable(_evidenceFiles);

  void setCategory(ComplaintCategory value) {
    if (_category == value) return;
    _category = value;
    notifyListeners();
  }

  void addEvidenceFiles(Iterable<SelectedPhotoBytes> files) {
    for (final file in files) {
      if (_evidenceFiles.length >= 4) break;
      _evidenceFiles.add(file);
    }
    notifyListeners();
  }

  void removeEvidenceAt(int index) {
    if (index < 0 || index >= _evidenceFiles.length) return;
    _evidenceFiles.removeAt(index);
    notifyListeners();
  }

  void clearDraft() {
    _category = ComplaintCategory.delay;
    _evidenceFiles.clear();
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadComplaints(
    String reporterId, {
    String locale = 'ar',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _complaints = await _repository.getMyComplaints(reporterId);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Complaint?> submitComplaint({
    required String reporterId,
    String? requestId,
    String? reportedUserId,
    required String subject,
    required String description,
    String locale = 'ar',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _repository.submitComplaint(
        reporterId: reporterId,
        requestId: requestId,
        reportedUserId: reportedUserId,
        category: _category,
        subject: subject,
        description: description,
        evidenceFiles: List<SelectedPhotoBytes>.from(_evidenceFiles),
      );
      _complaints = <Complaint>[created, ..._complaints];
      _evidenceFiles.clear();
      return created;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
