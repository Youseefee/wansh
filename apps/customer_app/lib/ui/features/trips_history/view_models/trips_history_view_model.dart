import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/rescue_request_repository.dart';
import '../../../core/error_formatter.dart';

enum TripHistoryFilter { all, active, completed, cancelled }

/// ViewModel for listing and filtering customer rescue trips.
class TripsHistoryViewModel extends ChangeNotifier {
  TripsHistoryViewModel({required this._repository});

  final RescueRequestRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  TripHistoryFilter _filter = TripHistoryFilter.all;
  List<RescueRequest> _trips = const <RescueRequest>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TripHistoryFilter get filter => _filter;
  List<RescueRequest> get allTrips => _trips;

  List<RescueRequest> get filteredTrips => switch (_filter) {
        TripHistoryFilter.all => _trips,
        TripHistoryFilter.active =>
          _trips.where((t) => !t.status.isTerminal).toList(growable: false),
        TripHistoryFilter.completed => _trips
            .where((t) => t.status == TripStatus.delivered)
            .toList(growable: false),
        TripHistoryFilter.cancelled => _trips
            .where(
              (t) =>
                  t.status == TripStatus.cancelled ||
                  t.status == TripStatus.expired,
            )
            .toList(growable: false),
      };

  void setFilter(TripHistoryFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadTrips(String customerId, {String locale = 'ar'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _trips = await _repository.getCustomerTrips(customerId);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
