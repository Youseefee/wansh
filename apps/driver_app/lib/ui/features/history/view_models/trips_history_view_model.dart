import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/driver_history_repository.dart';
import '../../../core/driver_session_controller.dart';

/// ViewModel displaying driver summary metrics (`total_trips`, `total_earnings`,
/// `avg_rating`), past trips, and received customer ratings.
class TripsHistoryViewModel extends ChangeNotifier {
  TripsHistoryViewModel({
    required this._historyRepository,
    required this._sessionController,
  });

  final DriverHistoryRepository _historyRepository;
  final DriverSessionController _sessionController;

  bool _isLoading = false;
  String? _errorMessage;
  List<RescueRequest> _trips = const <RescueRequest>[];
  List<TripRating> _ratings = const <TripRating>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<RescueRequest> get trips => _trips;
  List<TripRating> get ratings => _ratings;

  DriverProfile? get driverProfile => _sessionController.driverProfile;
  int get totalTrips => driverProfile?.totalTrips ?? 0;
  double get totalEarnings => driverProfile?.totalEarnings ?? 0.0;
  double get avgRating => driverProfile?.avgRating ?? 5.0;
  int get totalRatings => driverProfile?.totalRatings ?? 0;

  Future<void> loadHistory({bool refreshSession = false}) async {
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
        _historyRepository.getDriverTrips(driverId),
        _historyRepository.getDriverRatings(driverId),
      ]);
      _trips = results[0] as List<RescueRequest>;
      _ratings = results[1] as List<TripRating>;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
