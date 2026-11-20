import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/feedback_repository.dart';
import '../../../../data/repositories/rescue_request_repository.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for post-delivery driver rating (`public.ratings`).
class RateTripViewModel extends ChangeNotifier {
  RateTripViewModel({
    required this.requestId,
    required this._rescueRepository,
    required this._feedbackRepository,
  });

  final String requestId;
  final RescueRequestRepository _rescueRepository;
  final FeedbackRepository _feedbackRepository;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  RescueRequest? _request;
  TripRating? _existingRating;
  int _score = 5;
  final Set<String> _selectedTags = <String>{};
  String _comment = '';

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  RescueRequest? get request => _request;
  TripRating? get existingRating => _existingRating;
  int get score => _score;
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);

  Future<void> initialize({String locale = 'ar'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _rescueRepository.getRescueRequestById(requestId),
        _feedbackRepository.getRatingForRequest(requestId),
      ]);
      _request = results[0] as RescueRequest?;
      _existingRating = results[1] as TripRating?;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setScore(int value) {
    final clamped = value.clamp(1, 5);
    if (_score == clamped) return;
    _score = clamped;
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void setComment(String value) {
    _comment = value;
  }

  Future<TripRating?> submit({
    required String customerId,
    String locale = 'ar',
  }) async {
    final req = _request;
    if (req == null || req.driverId == null) {
      _errorMessage = locale.startsWith('ar')
          ? 'لا يمكن تقييم رحلة بدون سائق معين'
          : 'Cannot rate a trip without an assigned driver';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rating = await _feedbackRepository.submitRating(
        requestId: req.id,
        customerId: customerId,
        driverId: req.driverId!,
        score: _score,
        comment: _comment,
        tags: _selectedTags.toList(growable: false),
      );
      _existingRating = rating;
      return rating;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
