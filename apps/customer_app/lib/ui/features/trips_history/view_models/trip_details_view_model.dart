import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/feedback_repository.dart';
import '../../../../data/repositories/rescue_request_repository.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for inspecting a rescue trip's complete details, breakdown photos,
/// driver/winch summary, status logs, and rating status.
class TripDetailsViewModel extends ChangeNotifier {
  TripDetailsViewModel({
    required this.requestId,
    required this._rescueRepository,
    required this._feedbackRepository,
    WinchCatalogService? winchCatalog,
  }) : _winchCatalog = winchCatalog ?? const WinchCatalogService();

  final String requestId;
  final RescueRequestRepository _rescueRepository;
  final FeedbackRepository _feedbackRepository;
  final WinchCatalogService _winchCatalog;

  bool _isLoading = false;
  String? _errorMessage;

  RescueRequest? _request;
  WinchType? _winchType;
  DriverProfile? _driver;
  DriverWinch? _winch;
  List<TripStatusLog> _statusLogs = const <TripStatusLog>[];
  TripRating? _existingRating;
  Map<String, String> _photoUrls = const <String, String>{};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RescueRequest? get request => _request;
  WinchType? get winchType => _winchType;
  DriverProfile? get driver => _driver;
  DriverWinch? get winch => _winch;
  List<TripStatusLog> get statusLogs => _statusLogs;
  TripRating? get existingRating => _existingRating;
  Map<String, String> get photoUrls => _photoUrls;

  Future<void> load({String locale = 'ar'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _rescueRepository.getRescueRequestById(requestId);
      if (loaded == null) {
        _request = null;
        return;
      }
      _request = loaded;

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _winchCatalog.getWinchTypeById(loaded.winchTypeId).catchError((_) => null),
        _rescueRepository
            .getTripStatusLogs(loaded.id)
            .catchError((_) => <TripStatusLog>[]),
        _feedbackRepository
            .getRatingForRequest(loaded.id)
            .catchError((_) => null),
        if (loaded.driverId != null)
          _rescueRepository
              .getAssignedDriverInfo(loaded.driverId!)
              .catchError((_) => null),
        if (loaded.winchId != null)
          _rescueRepository
              .getAssignedWinchInfo(loaded.winchId!)
              .catchError((_) => null),
        if (loaded.breakdownPhotoPaths.isNotEmpty)
          _rescueRepository
              .getBreakdownPhotoSignedUrls(loaded.breakdownPhotoPaths)
              .catchError((_) => <String, String>{}),
      ]);

      var idx = 0;
      _winchType = results[idx++] as WinchType?;
      _statusLogs = results[idx++] as List<TripStatusLog>;
      _existingRating = results[idx++] as TripRating?;
      if (loaded.driverId != null) {
        _driver = results[idx++] as DriverProfile?;
      }
      if (loaded.winchId != null) {
        _winch = results[idx++] as DriverWinch?;
      }
      if (loaded.breakdownPhotoPaths.isNotEmpty) {
        _photoUrls = results[idx++] as Map<String, String>;
      }
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
