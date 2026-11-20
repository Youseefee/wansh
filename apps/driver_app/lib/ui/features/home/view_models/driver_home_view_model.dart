import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/driver_dispatch_repository.dart';
import '../../../../data/repositories/driver_trip_repository.dart';
import '../../../../data/services/location_service.dart';
import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';

/// ViewModel powering Driver Home: online/offline availability + `fleet:online`
/// Presence, private `driver:<driver_id>` dispatch listener, live offer
/// countdown timer, and `accept_rescue_offer` / `reject_rescue_offer` RPCs.
class DriverHomeViewModel extends ChangeNotifier {
  DriverHomeViewModel({
    required this._dispatchRepository,
    required this._tripRepository,
    required this._locationSource,
    required this._sessionController,
    required this._localeController,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DriverDispatchRepository _dispatchRepository;
  final DriverTripRepository _tripRepository;
  final DriverLocationSource _locationSource;
  final DriverSessionController _sessionController;
  final LocaleController _localeController;
  final DateTime Function() _clock;

  StreamSubscription<DispatchOfferEvent>? _offersSub;
  Timer? _countdownTimer;
  Timer? _onlineHeartbeatTimer;

  bool _isInitializing = false;
  bool _isTogglingOnline = false;
  bool _isRespondingToOffer = false;
  bool _isOnline = false;
  DriverPositionData? _currentPosition;
  DispatchOffer? _activeOffer;
  Duration _offerRemaining = Duration.zero;
  String? _statusMessage;
  String? _errorMessage;

  bool get isInitializing => _isInitializing;
  bool get isTogglingOnline => _isTogglingOnline;
  bool get isRespondingToOffer => _isRespondingToOffer;
  bool get isOnline => _isOnline;
  DriverPositionData? get currentPosition => _currentPosition;
  DispatchOffer? get activeOffer => _activeOffer;
  Duration get offerRemaining => _offerRemaining;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  DriverProfile? get driverProfile => _sessionController.driverProfile;
  String? get activeTripId => _sessionController.activeTripId;

  Future<void> initialize() async {
    final driver = _sessionController.driverProfile;
    if (driver == null) return;

    _isInitializing = true;
    _errorMessage = null;
    _isOnline = driver.isOnline;
    if (driver.currentLat != null && driver.currentLng != null) {
      _currentPosition = DriverPositionData(
        lat: driver.currentLat!,
        lng: driver.currentLng!,
      );
    }
    notifyListeners();

    try {
      await _refreshCurrentPositionSilently();
      final activeTrip = await _tripRepository.getActiveTrip(driver.id);
      _sessionController.setActiveTripId(activeTrip?.id);

      if (driver.isApproved) {
        _listenToDispatchChannel(driver.id);
        await _loadPendingOffers(driver.id);

        if (_isOnline && _currentPosition != null) {
          await _dispatchRepository.joinOnlinePresence(
            driverId: driver.id,
            lat: _currentPosition!.lat,
            lng: _currentPosition!.lng,
          );
          _startHeartbeatTimer();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshCurrentPositionSilently() async {
    try {
      _currentPosition = await _locationSource.getCurrentPosition();
    } catch (_) {
      // Keep cached driver coordinates when device GPS isn't granted yet.
    }
  }

  void _listenToDispatchChannel(String driverId) {
    unawaited(_offersSub?.cancel());
    _offersSub = _dispatchRepository.watchDriverOffers(driverId).listen(
      (event) {
        final offer = event.offer;
        if (event.eventType == RealtimeTopics.insertEvent) {
          if (offer.status == OfferStatus.pending &&
              !offer.isExpiredAt(_clock())) {
            _setActiveOffer(offer);
          }
        } else if (event.eventType == RealtimeTopics.updateEvent) {
          if (_activeOffer?.id == offer.id) {
            if (offer.status != OfferStatus.pending) {
              _clearActiveOffer();
              _statusMessage = DriverStrings.t(
                _localeController.localeCode,
                'تم إغلاق العرض (${WenshyLabels.offerStatus(offer.status, locale: _localeController.localeCode)}).',
                'Offer closed (${WenshyLabels.offerStatus(offer.status, locale: _localeController.localeCode)}).',
              );
              notifyListeners();
            } else {
              _setActiveOffer(offer);
            }
          }
        }
      },
    );
  }

  Future<void> _loadPendingOffers(String driverId) async {
    final pending = await _dispatchRepository.getPendingOffers(driverId);
    final now = _clock();
    for (final offer in pending) {
      if (!offer.isExpiredAt(now)) {
        _setActiveOffer(offer);
        break;
      }
    }
  }

  void _setActiveOffer(DispatchOffer offer) {
    _activeOffer = offer;
    _offerRemaining = offer.remainingTime(_clock());
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _activeOffer;
      if (current == null) {
        _countdownTimer?.cancel();
        return;
      }
      final left = current.remainingTime(_clock());
      _offerRemaining = left;
      if (left <= Duration.zero) {
        _clearActiveOffer();
        _statusMessage = DriverStrings.t(
          _localeController.localeCode,
          'انتهت مهلة عرض الإنقاذ.',
          'Rescue offer timed out.',
        );
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void _clearActiveOffer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _activeOffer = null;
    _offerRemaining = Duration.zero;
    notifyListeners();
  }

  Future<void> toggleOnline(bool goOnline) async {
    final driver = _sessionController.driverProfile;
    if (driver == null || _isTogglingOnline) return;

    _isTogglingOnline = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      DriverPositionData? pos;
      try {
        pos = await _locationSource.getCurrentPosition();
        _currentPosition = pos;
      } catch (e) {
        if (goOnline) {
          if (_currentPosition == null) rethrow;
          pos = _currentPosition;
        } else {
          pos = _currentPosition ??
              const DriverPositionData(lat: 30.0444, lng: 31.2357);
        }
      }

      if (pos == null) {
        throw const DriverLocationException(
          'no_location',
          'Unable to determine GPS position.',
        );
      }

      await _dispatchRepository.syncLocationAndOnlineStatus(
        lat: pos.lat,
        lng: pos.lng,
        heading: pos.heading,
        speedKmh: pos.speedKmh,
        isOnline: goOnline,
      );

      _isOnline = goOnline;
      _sessionController.updateDriverProfileCache(
        driver.copyWith(
          isOnline: goOnline,
          currentLat: pos.lat,
          currentLng: pos.lng,
        ),
      );

      if (goOnline) {
        await _dispatchRepository.joinOnlinePresence(
          driverId: driver.id,
          lat: pos.lat,
          lng: pos.lng,
        );
        _listenToDispatchChannel(driver.id);
        await _loadPendingOffers(driver.id);
        _startHeartbeatTimer();
      } else {
        _onlineHeartbeatTimer?.cancel();
        _onlineHeartbeatTimer = null;
        await _dispatchRepository.leaveOnlinePresence();
      }
    } catch (e) {
      _errorMessage = _localizeError(e);
    } finally {
      _isTogglingOnline = false;
      notifyListeners();
    }
  }

  void _startHeartbeatTimer() {
    _onlineHeartbeatTimer?.cancel();
    _onlineHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_sendHeartbeatLocation()),
    );
  }

  Future<void> _sendHeartbeatLocation() async {
    if (!_isOnline) return;
    try {
      final pos = await _locationSource.getCurrentPosition();
      _currentPosition = pos;
      await _dispatchRepository.syncLocationAndOnlineStatus(
        lat: pos.lat,
        lng: pos.lng,
        heading: pos.heading,
        speedKmh: pos.speedKmh,
      );
      notifyListeners();
    } catch (_) {
      // Transient GPS failure will retry on the next 30s tick.
    }
  }

  /// Accepts the current [DispatchOffer] via `accept_rescue_offer` RPC.
  /// Returns the claimed `requestId` on success, or `null` if unavailable.
  Future<String?> acceptCurrentOffer() async {
    final offer = _activeOffer;
    if (offer == null || _isRespondingToOffer) return null;

    _isRespondingToOffer = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final result = await _dispatchRepository.acceptOffer(offer.id);
      _clearActiveOffer();

      if (result.accepted && result.requestId != null) {
        _sessionController.setActiveTripId(result.requestId);
        return result.requestId;
      }

      _errorMessage = DriverStrings.acceptFailureMessage(
        result.reason,
        _localeController.localeCode,
      );
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isRespondingToOffer = false;
      notifyListeners();
    }
  }

  /// Rejects the current [DispatchOffer] via `reject_rescue_offer` RPC.
  Future<void> rejectCurrentOffer({String? reason}) async {
    final offer = _activeOffer;
    if (offer == null || _isRespondingToOffer) return;

    _isRespondingToOffer = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dispatchRepository.rejectOffer(offer.id, reason: reason);
      _clearActiveOffer();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isRespondingToOffer = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    if (_errorMessage == null && _statusMessage == null) return;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  String _localizeError(Object error) {
    final locale = _localeController.localeCode;
    if (error is DriverLocationException) {
      return switch (error.code) {
        'location_service_disabled' => DriverStrings.t(
            locale,
            'يرجى تفعيل خدمة الموقع (GPS) على الهاتف للاتصال.',
            'Please enable device location services (GPS) to go online.',
          ),
        'permission_denied' || 'permission_denied_forever' => DriverStrings.t(
            locale,
            'صلاحية الموقع مطلوبة لتلقي طلبات الإنقاذ القريبة.',
            'Location permission is required to receive nearby rescue jobs.',
          ),
        _ => error.message,
      };
    }
    return error.toString();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _onlineHeartbeatTimer?.cancel();
    unawaited(_offersSub?.cancel());
    unawaited(_dispatchRepository.disposeSubscriptions());
    super.dispose();
  }
}
