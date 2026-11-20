import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/driver_trip_repository.dart';
import '../../../../data/services/external_launcher_service.dart';
import '../../../../data/services/location_service.dart';
import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';

/// Destination coordinates and stage classification for external turn-by-turn
/// navigation (Google Maps / Waze).
@immutable
class TripNavigationTarget {
  const TripNavigationTarget({
    required this.lat,
    required this.lng,
    required this.isDropoff,
  });

  final double lat;
  final double lng;
  final bool isDropoff;
}

/// ViewModel orchestrating active rescue trip execution:
/// - Stage progression via `driver_update_trip_stage` RPC
/// - Real road polyline loading via `WenshyGeoService.getDrivingRoute`
/// - Direct customer phone call & external Google Maps / Waze navigation
/// - Live GPS broadcast (`driver_location`) on private `trip:<request_id>`
/// - Throttled `driver_update_location` RPC sync every 20 seconds
/// - Trip state change subscription (`trip:<request_id>`)
class ActiveTripViewModel extends ChangeNotifier {
  ActiveTripViewModel({
    required this._tripRepository,
    required this._locationSource,
    required this._sessionController,
    required this._localeController,
    WenshyGeoService? geoService,
    DriverExternalLauncher? externalLauncher,
    DateTime Function()? clock,
    this._dbSyncInterval = const Duration(seconds: 20),
    this._routeRefreshInterval = const Duration(seconds: 30),
  })  : _geoService = geoService ?? const WenshyGeoService(),
        _externalLauncher =
            externalLauncher ?? const UrlLauncherDriverExternalLauncher(),
        _clock = clock ?? DateTime.now;

  final DriverTripRepository _tripRepository;
  final DriverLocationSource _locationSource;
  final DriverSessionController _sessionController;
  final LocaleController _localeController;
  final WenshyGeoService _geoService;
  final DriverExternalLauncher _externalLauncher;
  final DateTime Function() _clock;
  final Duration _dbSyncInterval;
  final Duration _routeRefreshInterval;

  StreamSubscription<DriverPositionData>? _gpsSub;
  DateTime? _lastDbSyncAt;
  DateTime? _lastRouteFetchAt;
  ({double lat, double lng})? _lastRouteOrigin;
  bool? _lastRouteWasDropoffLeg;
  int _routeFetchSeq = 0;

  bool _isLoading = false;
  bool _isUpdatingStage = false;
  bool _isGpsStreaming = false;
  bool _isLoadingRoute = false;
  RescueRequest? _trip;
  UserProfile? _customerProfile;
  List<TripStatusLog> _statusLogs = const <TripStatusLog>[];
  Map<String, String> _breakdownPhotoUrls = const <String, String>{};
  DriverPositionData? _driverPosition;
  RoadRouteResult? _activeRoute;
  List<LatLng> _routePolylinePoints = const <LatLng>[];
  String? _errorMessage;
  int _broadcastCount = 0;
  int _dbSyncCount = 0;

  bool get isLoading => _isLoading;
  bool get isUpdatingStage => _isUpdatingStage;
  bool get isGpsStreaming => _isGpsStreaming;
  bool get isLoadingRoute => _isLoadingRoute;
  RescueRequest? get trip => _trip;
  UserProfile? get customerProfile => _customerProfile;
  List<TripStatusLog> get statusLogs => _statusLogs;
  Map<String, String> get breakdownPhotoUrls => _breakdownPhotoUrls;
  DriverPositionData? get driverPosition => _driverPosition;
  RoadRouteResult? get activeRoute => _activeRoute;
  List<LatLng> get routePolylinePoints => _routePolylinePoints;
  String? get errorMessage => _errorMessage;

  /// Exposed for unit test verification of broadcast vs. 20s DB sync throttling.
  int get broadcastCount => _broadcastCount;
  int get dbSyncCount => _dbSyncCount;

  TripStatus? get nextStage => _trip?.status.nextDriverStage;
  String get localeCode => _localeController.localeCode;

  /// Whether the trip has reached or passed `vehicle_loaded` (heading to dropoff).
  bool get isDropoffLeg {
    final status = _trip?.status;
    return status == TripStatus.vehicleLoaded ||
        status == TripStatus.enRouteToDropoff ||
        status == TripStatus.delivered;
  }

  /// Active turn-by-turn navigation target:
  /// - Pickup coordinates for `driver_assigned`, `en_route_to_pickup`, `arrived_at_pickup`
  /// - Dropoff coordinates for `vehicle_loaded`, `en_route_to_dropoff`
  /// - `null` for terminal or non-active trips
  TripNavigationTarget? get navigationTarget {
    final current = _trip;
    if (current == null || !current.status.isActiveWithDriver) return null;
    if (isDropoffLeg) {
      return TripNavigationTarget(
        lat: current.dropoffLat,
        lng: current.dropoffLng,
        isDropoff: true,
      );
    }
    return TripNavigationTarget(
      lat: current.pickupLat,
      lng: current.pickupLng,
      isDropoff: false,
    );
  }

  String? get customerPhone {
    final raw = _customerProfile?.phone?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<void> loadTrip(String requestId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _tripRepository.getTripById(requestId);
      if (fetched == null) {
        _errorMessage = 'Trip not found';
        return;
      }
      _trip = fetched;

      // Seed driver position from cached profile so pickup route can load
      // immediately even before the first live GPS stream tick arrives.
      final cachedDriver = _sessionController.driverProfile;
      if (_driverPosition == null &&
          cachedDriver?.currentLat != null &&
          cachedDriver?.currentLng != null) {
        _driverPosition = DriverPositionData(
          lat: cachedDriver!.currentLat!,
          lng: cachedDriver.currentLng!,
        );
      }

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _tripRepository.getCustomerProfile(fetched.customerId),
        _tripRepository.getTripStatusLogs(fetched.id),
        _tripRepository.getBreakdownPhotoUrls(fetched.breakdownPhotoPaths),
      ]);

      _customerProfile = results[0] as UserProfile?;
      _statusLogs = results[1] as List<TripStatusLog>;
      _breakdownPhotoUrls = results[2] as Map<String, String>;

      if (fetched.status.isActiveWithDriver) {
        _sessionController.setActiveTripId(fetched.id);
        await _tripRepository.openTripChannel(
          fetched.id,
          onTripChanged: _handleRemoteTripChange,
        );
        _startGpsBroadcaster(fetched.id);
      } else {
        await _stopStreamingAndChannel();
      }

      await refreshRoute(force: true);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches the driving road polyline via [WenshyGeoService.getDrivingRoute]:
  /// - Before `vehicle_loaded`: driver -> pickup (when driver GPS is known)
  /// - From `vehicle_loaded` onward: pickup -> dropoff
  Future<void> refreshRoute({bool force = false}) async {
    final current = _trip;
    if (current == null) return;

    final dropoffLeg = isDropoffLeg;
    final double fromLat;
    final double fromLng;
    final double toLat;
    final double toLng;

    if (dropoffLeg) {
      fromLat = current.pickupLat;
      fromLng = current.pickupLng;
      toLat = current.dropoffLat;
      toLng = current.dropoffLng;
    } else if (_driverPosition != null) {
      fromLat = _driverPosition!.lat;
      fromLng = _driverPosition!.lng;
      toLat = current.pickupLat;
      toLng = current.pickupLng;
    } else {
      // Driver coordinates not available yet: show pickup -> dropoff preview
      // until GPS emits the first driver fix.
      fromLat = current.pickupLat;
      fromLng = current.pickupLng;
      toLat = current.dropoffLat;
      toLng = current.dropoffLng;
    }

    final now = _clock().toUtc();
    if (!force &&
        _lastRouteWasDropoffLeg == dropoffLeg &&
        _lastRouteFetchAt != null &&
        _lastRouteOrigin != null) {
      final elapsed = now.difference(_lastRouteFetchAt!);
      final movedKm = WenshyGeoService.haversineDistanceKm(
        _lastRouteOrigin!.lat,
        _lastRouteOrigin!.lng,
        fromLat,
        fromLng,
      );
      if (elapsed < _routeRefreshInterval && movedKm < 0.3) {
        return;
      }
    }

    final fetchSeq = ++_routeFetchSeq;
    _isLoadingRoute = true;
    _lastRouteFetchAt = now;
    _lastRouteOrigin = (lat: fromLat, lng: fromLng);
    _lastRouteWasDropoffLeg = dropoffLeg;
    notifyListeners();

    try {
      final route = await _geoService.getDrivingRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
      if (fetchSeq != _routeFetchSeq) return;
      _activeRoute = route;
      _routePolylinePoints = List<LatLng>.unmodifiable(
        route.points.map((p) => LatLng(p.lat, p.lng)),
      );
    } catch (_) {
      // WenshyGeoService already falls back cleanly, but guard custom fakes too.
    } finally {
      if (fetchSeq == _routeFetchSeq) {
        _isLoadingRoute = false;
        notifyListeners();
      }
    }
  }

  /// Launches the device dialer to call the assigned customer (`tel:<phone>`).
  Future<bool> callCustomer() async {
    final phone = customerPhone;
    if (phone == null) return false;
    final launched = await _externalLauncher.callPhone(phone);
    if (!launched) {
      _errorMessage = DriverStrings.externalLaunchFailed(localeCode);
      notifyListeners();
    }
    return launched;
  }

  /// Launches turn-by-turn external navigation (Google Maps or Waze) to the
  /// current trip leg destination (Pickup before `vehicle_loaded`, Dropoff
  /// on/after `vehicle_loaded`).
  Future<bool> openExternalNavigation({
    ExternalNavProvider provider = ExternalNavProvider.googleMaps,
  }) async {
    final target = navigationTarget;
    if (target == null) return false;
    final launched = await _externalLauncher.navigateTo(
      lat: target.lat,
      lng: target.lng,
      provider: provider,
    );
    if (!launched) {
      _errorMessage = DriverStrings.externalLaunchFailed(localeCode);
      notifyListeners();
    }
    return launched;
  }

  void _handleRemoteTripChange(RescueRequest updated) {
    final previousDropoffLeg = isDropoffLeg;
    _trip = updated;
    if (updated.status.isTerminal) {
      _sessionController.setActiveTripId(null);
      unawaited(_stopStreamingAndChannel());
      unawaited(_sessionController.refreshSession());
    } else if (previousDropoffLeg != isDropoffLeg) {
      unawaited(refreshRoute(force: true));
    }
    notifyListeners();
  }

  void _startGpsBroadcaster(String requestId) {
    unawaited(_gpsSub?.cancel());
    _isGpsStreaming = true;
    _gpsSub = _locationSource.getPositionStream().listen(
      (position) {
        unawaited(_handlePositionUpdate(requestId, position));
      },
      onError: (_) {
        _isGpsStreaming = false;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> _handlePositionUpdate(
    String requestId,
    DriverPositionData position,
  ) async {
    final currentTrip = _trip;
    if (currentTrip == null ||
        currentTrip.id != requestId ||
        !currentTrip.status.isActiveWithDriver) {
      return;
    }

    final hadPositionBefore = _driverPosition != null;
    _driverPosition = position;
    final now = _clock().toUtc();
    final point = TripLocationPoint(
      requestId: requestId,
      driverId: _sessionController.driverId,
      lat: position.lat,
      lng: position.lng,
      heading: position.heading,
      speedKmh: position.speedKmh,
      recordedAt: now,
    );

    try {
      await _tripRepository.broadcastLiveLocation(
        requestId: requestId,
        point: point,
      );
      _broadcastCount++;
    } catch (_) {
      // Ephemeral broadcast errors should not break GPS loop.
    }

    final shouldSyncDb = _lastDbSyncAt == null ||
        now.difference(_lastDbSyncAt!) >= _dbSyncInterval;
    if (shouldSyncDb) {
      _lastDbSyncAt = now;
      try {
        await _tripRepository.syncTripLocationToDb(
          requestId: requestId,
          point: point,
        );
        _dbSyncCount++;
      } catch (_) {
        // Keep streaming even if a throttled DB sync fails transiently.
      }
    }

    if (!isDropoffLeg) {
      unawaited(refreshRoute(force: !hadPositionBefore));
    }

    notifyListeners();
  }

  Future<bool> advanceToNextStage({String? notes, double? finalPrice}) async {
    final current = _trip;
    final targetStage = current?.status.nextDriverStage;
    if (current == null || targetStage == null || _isUpdatingStage) {
      return false;
    }

    final previousDropoffLeg = isDropoffLeg;
    _isUpdatingStage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _tripRepository.advanceTripStage(
        requestId: current.id,
        nextStatus: targetStage,
        lat: _driverPosition?.lat,
        lng: _driverPosition?.lng,
        notes: notes,
        finalPrice:
            targetStage == TripStatus.delivered ? finalPrice : null,
      );

      _trip = updated;
      _statusLogs = await _tripRepository.getTripStatusLogs(updated.id);

      if (updated.status.isTerminal) {
        _sessionController.setActiveTripId(null);
        await _stopStreamingAndChannel();
        await _sessionController.refreshSession();
      } else if (previousDropoffLeg != isDropoffLeg) {
        await refreshRoute(force: true);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUpdatingStage = false;
      notifyListeners();
    }
  }

  Future<bool> cancelTrip({String? reason}) async {
    final current = _trip;
    if (current == null || !current.status.isCancellable || _isUpdatingStage) {
      return false;
    }

    _isUpdatingStage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _tripRepository.cancelTrip(
        requestId: current.id,
        reason: reason,
      );
      final refreshed = await _tripRepository.getTripById(current.id);
      if (refreshed != null) {
        _trip = refreshed;
      }
      _sessionController.setActiveTripId(null);
      await _stopStreamingAndChannel();
      await _sessionController.refreshSession();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUpdatingStage = false;
      notifyListeners();
    }
  }

  Future<void> _stopStreamingAndChannel() async {
    _isGpsStreaming = false;
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _tripRepository.closeTripChannel();
  }

  @override
  void dispose() {
    unawaited(_stopStreamingAndChannel());
    super.dispose();
  }
}
