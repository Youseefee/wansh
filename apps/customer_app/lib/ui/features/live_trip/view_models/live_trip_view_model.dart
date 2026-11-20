import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/map_and_quote_repository.dart';
import '../../../../data/repositories/rescue_request_repository.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for the Live Trip Tracker screen:
/// - Subscribes to private Realtime channel `trip:<request_id>`
/// - Handles `UPDATE` (`realtime.broadcast_changes`) and `driver_location`
/// - Fetches the real driving route polyline via [MapAndQuoteRepository]
/// - Loads assigned driver, winch, and status audit logs
/// - Supports Wave-2+ dispatch retry (`dispatch_rescue_request` RPC)
/// - Supports trip cancellation (`cancel_rescue_request` RPC)
class LiveTripViewModel extends ChangeNotifier {
  LiveTripViewModel({
    required this.requestId,
    required this._rescueRepository,
    this._mapRepository,
    WinchCatalogService? winchCatalog,
    RescueRequest? initialRequest,
    DispatchResult? initialDispatch,
  })  : _winchCatalog = winchCatalog ?? const WinchCatalogService(),
        _request = initialRequest,
        _lastDispatch = initialDispatch;

  final String requestId;
  final RescueRequestRepository _rescueRepository;
  final MapAndQuoteRepository? _mapRepository;
  final WinchCatalogService _winchCatalog;

  TripRealtimeSubscription? _subscription;
  bool _disposed = false;

  bool _isLoading = false;
  bool _isDispatchingWave = false;
  bool _isCancelling = false;
  bool _realtimeConnected = false;
  String? _errorMessage;
  String? _actionMessage;

  RescueRequest? _request;
  WinchType? _winchType;
  DriverProfile? _driver;
  DriverWinch? _winch;
  List<TripStatusLog> _statusLogs = const <TripStatusLog>[];
  DispatchResult? _lastDispatch;

  TripLocationPoint? _latestDriverPoint;
  LatLng? _driverLatLng;
  List<LatLng> _routePolyline = const <LatLng>[];
  String? _loadedRouteKey;

  bool get isLoading => _isLoading;
  bool get isDispatchingWave => _isDispatchingWave;
  bool get isCancelling => _isCancelling;
  bool get realtimeConnected => _realtimeConnected;
  String? get errorMessage => _errorMessage;
  String? get actionMessage => _actionMessage;

  RescueRequest? get request => _request;
  WinchType? get winchType => _winchType;
  DriverProfile? get driver => _driver;
  DriverWinch? get winch => _winch;
  List<TripStatusLog> get statusLogs => _statusLogs;
  DispatchResult? get lastDispatch => _lastDispatch;
  TripLocationPoint? get latestDriverPoint => _latestDriverPoint;
  LatLng? get driverLatLng => _driverLatLng;

  /// Driving road polyline for the trip; falls back to pickup->dropoff line
  /// when OSRM hasn't returned yet.
  List<LatLng> get routePolyline {
    if (_routePolyline.length >= 2) return _routePolyline;
    final req = _request;
    if (req == null) return const <LatLng>[];
    return <LatLng>[
      LatLng(req.pickupLat, req.pickupLng),
      LatLng(req.dropoffLat, req.dropoffLng),
    ];
  }

  Future<void> initialize({String locale = 'ar'}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _loadTripState(loadWinchType: true);
      _subscribeRealtime(locale: locale);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refresh({String locale = 'ar'}) async {
    _errorMessage = null;
    try {
      await _loadTripState(loadWinchType: _winchType == null);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    }
    _safeNotify();
  }

  Future<void> _loadTripState({bool loadWinchType = false}) async {
    final loaded = await _rescueRepository.getRescueRequestById(requestId);
    if (loaded == null) {
      return;
    }
    _request = loaded;

    if (loadWinchType) {
      _winchType = await _winchCatalog
          .getWinchTypeById(loaded.winchTypeId)
          .catchError((_) => null);
    }

    await Future.wait<void>(<Future<void>>[
      _loadCounterpartyAndLogs(loaded),
      _loadDrivingRoute(loaded),
    ]);
  }

  Future<void> _loadDrivingRoute(RescueRequest req) async {
    final mapRepo = _mapRepository;
    if (mapRepo == null) return;
    final key =
        '${req.pickupLat},${req.pickupLng}->${req.dropoffLat},${req.dropoffLng}';
    if (_loadedRouteKey == key && _routePolyline.length >= 2) return;
    _loadedRouteKey = key;
    try {
      final result = await mapRepo.getDrivingRoute(
        fromLat: req.pickupLat,
        fromLng: req.pickupLng,
        toLat: req.dropoffLat,
        toLng: req.dropoffLng,
      );
      if (_disposed) return;
      if (result.points.length >= 2) {
        _routePolyline = result.points
            .map((p) => LatLng(p.lat, p.lng))
            .toList(growable: false);
      }
    } catch (_) {
      // Fallback straight-line polyline remains in place via routePolyline getter.
    }
  }

  Future<void> _loadCounterpartyAndLogs(RescueRequest req) async {
    final futures = <Future<dynamic>>[
      _rescueRepository.getTripStatusLogs(req.id).catchError((_) => <TripStatusLog>[]),
      if (req.driverId != null && (_driver == null || _driver!.id != req.driverId))
        _rescueRepository.getAssignedDriverInfo(req.driverId!).catchError((_) => null),
      if (req.winchId != null && (_winch == null || _winch!.id != req.winchId))
        _rescueRepository.getAssignedWinchInfo(req.winchId!).catchError((_) => null),
      if (req.driverId != null && _driverLatLng == null)
        _rescueRepository.getLatestDriverLocation(req.id).catchError((_) => null),
    ];

    final results = await Future.wait<dynamic>(futures);
    var idx = 0;
    _statusLogs = results[idx++] as List<TripStatusLog>;

    if (req.driverId != null && (_driver == null || _driver!.id != req.driverId)) {
      _driver = results[idx++] as DriverProfile?;
      if (_driver?.currentLat != null &&
          _driver?.currentLng != null &&
          _driverLatLng == null) {
        _driverLatLng = LatLng(_driver!.currentLat!, _driver!.currentLng!);
      }
    }
    if (req.winchId != null && (_winch == null || _winch!.id != req.winchId)) {
      _winch = results[idx++] as DriverWinch?;
    }
    if (req.driverId != null && _driverLatLng == null && idx < results.length) {
      final point = results[idx] as TripLocationPoint?;
      if (point != null) {
        _latestDriverPoint = point;
        _driverLatLng = LatLng(point.lat, point.lng);
      }
    }
  }

  void _subscribeRealtime({required String locale}) {
    unawaited(_subscription?.dispose());
    _subscription = _rescueRepository.subscribeToTrip(
      requestId: requestId,
      onTripUpdate: (updated, _) => unawaited(_handleTripBroadcast(updated)),
      onDriverLocation: _handleDriverLocationBroadcast,
      onStatus: (status, error) {
        _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
        if (status == RealtimeSubscribeStatus.channelError && error != null) {
          _errorMessage = ErrorFormatter.format(error, locale: locale);
        }
        _safeNotify();
      },
    );
  }

  Future<void> _handleTripBroadcast(RescueRequest? updated) async {
    if (_disposed) return;
    if (updated != null) {
      final driverChanged = updated.driverId != _request?.driverId ||
          updated.winchId != _request?.winchId;
      _request = updated;
      _safeNotify();

      if (driverChanged || _statusLogs.isEmpty || updated.status != TripStatus.searching) {
        await _loadCounterpartyAndLogs(updated);
        _safeNotify();
      }
    } else {
      await _loadTripState();
      _safeNotify();
    }
  }

  void _handleDriverLocationBroadcast(TripLocationPoint point) {
    if (_disposed) return;
    _latestDriverPoint = point;
    _driverLatLng = LatLng(point.lat, point.lng);
    _safeNotify();
  }

  /// Wave-2+ dispatch retry calling `dispatch_rescue_request` RPC with an
  /// expanded search radius.
  Future<DispatchResult?> retryNextWave({String locale = 'ar'}) async {
    final current = _request;
    if (current == null || current.status != TripStatus.searching) {
      return null;
    }

    _isDispatchingWave = true;
    _actionMessage = null;
    _errorMessage = null;
    _safeNotify();

    try {
      final nextWave = current.currentWave + 1;
      final radius = (15000 + (nextWave - 1) * 10000).clamp(15000, 100000);
      final result = await _rescueRepository.dispatchNextWave(
        requestId: current.id,
        radiusMeters: radius,
        waveNumber: nextWave,
        batchSize: 5,
        offerTtlSeconds: 45,
      );
      _lastDispatch = result;
      _request = current.copyWith(currentWave: nextWave);

      final isAr = locale.toLowerCase().startsWith('ar');
      if (result.dispatchedCount > 0) {
        _actionMessage = isAr
            ? 'تم إرسال الطلب في الموجة #$nextWave إلى ${result.dispatchedCount} سائقين'
            : 'Dispatched Wave #$nextWave to ${result.dispatchedCount} drivers';
      } else {
        _actionMessage = isAr
            ? 'لم يتم العثور على سائقين إضافيين في هذا النطاق حالياً.'
            : 'No additional drivers found in range right now.';
      }
      return result;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return null;
    } finally {
      _isDispatchingWave = false;
      _safeNotify();
    }
  }

  Future<bool> cancelTrip({
    String? reason,
    String locale = 'ar',
  }) async {
    final current = _request;
    if (current == null || !current.status.isCancellable) return false;

    _isCancelling = true;
    _errorMessage = null;
    _actionMessage = null;
    _safeNotify();

    try {
      final cancelled = await _rescueRepository.cancelRescueRequest(
        requestId: current.id,
        reason: reason,
      );
      if (cancelled) {
        await _loadTripState();
      }
      return cancelled;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return false;
    } finally {
      _isCancelling = false;
      _safeNotify();
    }
  }

  void clearActionMessage() {
    _actionMessage = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.dispose());
    super.dispose();
  }
}
