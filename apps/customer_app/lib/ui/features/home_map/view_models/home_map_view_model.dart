import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/map_and_quote_repository.dart';
import '../../../../data/repositories/models.dart';
import '../../../../data/repositories/rescue_request_repository.dart';
import '../../../core/error_formatter.dart';

/// Default fallback coordinates (Downtown Cairo) if device GPS is unavailable.
const LatLng kDefaultCairoLatLng = LatLng(30.0444, 31.2357);

/// ViewModel for the Customer Home Map screen:
/// - Detects current GPS position and reverse-geocodes addresses via Nominatim
/// - Searches places (Arabic/English) via [WenshyGeoService.searchPlaces]
/// - Fetches real driving road routes via [WenshyGeoService.getDrivingRoute]
/// - Selects Pickup (breakdown) and Dropoff (destination) coordinates/addresses
/// - Loads active [WinchType] catalog and fetches nearby online winches
///   via `find_nearest_drivers` RPC
class HomeMapViewModel extends ChangeNotifier {
  HomeMapViewModel({
    required this._mapRepository,
    required this._rescueRepository,
  });

  final MapAndQuoteRepository _mapRepository;
  final RescueRequestRepository _rescueRepository;

  bool _disposed = false;
  bool _isInitializing = false;
  bool _isLocating = false;
  bool _isLoadingDrivers = false;
  bool _isReverseGeocoding = false;
  bool _isLoadingRoute = false;
  bool _isSearchingPlaces = false;
  bool _locationFallbackUsed = false;
  String? _errorMessage;

  LatLng _pickupPoint = kDefaultCairoLatLng;
  LatLng? _dropoffPoint;
  String _pickupAddress = 'القاهرة - موقع العطل (30.0444, 31.2357)';
  String _dropoffAddress = '';
  MapPickMode _pickMode = MapPickMode.pickup;

  RoadRouteResult? _roadRoute;
  List<GeoPlaceSuggestion> _searchResults = const <GeoPlaceSuggestion>[];

  List<WinchType> _winchTypes = const <WinchType>[];
  WinchType? _selectedWinchType;
  List<NearbyDriver> _nearbyDrivers = const <NearbyDriver>[];
  NearbyDriver? _focusedDriver;
  RescueRequest? _activeTrip;

  // Monotonic counters prevent stale async network responses from overwriting
  // newer taps/searches.
  int _pickupGeocodeSeq = 0;
  int _dropoffGeocodeSeq = 0;
  int _routeSeq = 0;
  int _searchSeq = 0;

  bool get isInitializing => _isInitializing;
  bool get isLocating => _isLocating;
  bool get isLoadingDrivers => _isLoadingDrivers;
  bool get isReverseGeocoding => _isReverseGeocoding;
  bool get isLoadingRoute => _isLoadingRoute;
  bool get isSearchingPlaces => _isSearchingPlaces;
  bool get locationFallbackUsed => _locationFallbackUsed;
  String? get errorMessage => _errorMessage;

  LatLng get pickupPoint => _pickupPoint;
  LatLng? get dropoffPoint => _dropoffPoint;
  String get pickupAddress => _pickupAddress;
  String get dropoffAddress => _dropoffAddress;
  MapPickMode get pickMode => _pickMode;

  RoadRouteResult? get roadRoute => _roadRoute;
  double? get routeDistanceKm => _roadRoute?.distanceKm;
  int? get routeDurationMinutes => _roadRoute?.durationMinutes;
  List<GeoPlaceSuggestion> get searchResults => _searchResults;

  /// Road polyline coordinates for `FlutterMap`. Falls back to a 2-point line
  /// while OSRM is loading or when dropoff is set without a route yet.
  List<LatLng> get routePolylinePoints {
    final dropoff = _dropoffPoint;
    if (dropoff == null) return const <LatLng>[];
    final route = _roadRoute;
    if (route != null && route.points.length >= 2) {
      return route.points
          .map((p) => LatLng(p.lat, p.lng))
          .toList(growable: false);
    }
    return <LatLng>[_pickupPoint, dropoff];
  }

  List<WinchType> get winchTypes => _winchTypes;
  WinchType? get selectedWinchType => _selectedWinchType;
  List<NearbyDriver> get nearbyDrivers => _nearbyDrivers;
  NearbyDriver? get focusedDriver => _focusedDriver;
  RescueRequest? get activeTrip => _activeTrip;

  bool get canProceedToRequest =>
      _dropoffPoint != null && _selectedWinchType != null;

  static String formatCoordinateLabel(LatLng point, {required bool isArabic}) {
    final lat = point.latitude.toStringAsFixed(4);
    final lng = point.longitude.toStringAsFixed(4);
    return isArabic ? 'موقع محدد ($lat, $lng)' : 'Pinned ($lat, $lng)';
  }

  Future<void> initialize({
    String? customerId,
    String locale = 'ar',
  }) async {
    _isInitializing = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _mapRepository.getActiveWinchTypes(),
        _mapRepository.getCurrentLocation().catchError((_) => null),
        if (customerId != null)
          _rescueRepository
              .getLatestActiveTrip(customerId)
              .catchError((_) => null),
      ]);

      _winchTypes = results[0] as List<WinchType>;
      if (_winchTypes.isNotEmpty && _selectedWinchType == null) {
        _selectedWinchType = _winchTypes.first;
      }

      final detected = results[1] as LatLng?;
      final isAr = locale.toLowerCase().startsWith('ar');
      if (detected != null) {
        _pickupPoint = detected;
        _pickupAddress = formatCoordinateLabel(detected, isArabic: isAr);
        _locationFallbackUsed = false;
      } else {
        _locationFallbackUsed = true;
        _pickupAddress = formatCoordinateLabel(_pickupPoint, isArabic: isAr);
      }

      if (customerId != null && results.length > 2) {
        _activeTrip = results[2] as RescueRequest?;
      }

      await Future.wait<void>(<Future<void>>[
        refreshNearbyDrivers(locale: locale),
        _reverseGeocodePickup(_pickupPoint, locale: locale),
      ]);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isInitializing = false;
      _safeNotify();
    }
  }

  Future<void> refreshActiveTrip(String? customerId) async {
    if (customerId == null) return;
    try {
      _activeTrip = await _rescueRepository.getLatestActiveTrip(customerId);
      _safeNotify();
    } catch (_) {
      // Ignore silent refresh failures.
    }
  }

  Future<LatLng?> detectCurrentLocation({String locale = 'ar'}) async {
    _isLocating = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final detected = await _mapRepository.getCurrentLocation();
      final isAr = locale.toLowerCase().startsWith('ar');
      if (detected != null) {
        _pickupPoint = detected;
        _pickupAddress = formatCoordinateLabel(detected, isArabic: isAr);
        _locationFallbackUsed = false;
        _safeNotify();

        await Future.wait<void>(<Future<void>>[
          refreshNearbyDrivers(locale: locale),
          _reverseGeocodePickup(detected, locale: locale),
          if (_dropoffPoint != null) refreshDrivingRoute(),
        ]);
        return detected;
      } else {
        _locationFallbackUsed = true;
        return null;
      }
    } catch (e) {
      _locationFallbackUsed = true;
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return null;
    } finally {
      _isLocating = false;
      _safeNotify();
    }
  }

  void setPickMode(MapPickMode mode) {
    if (_pickMode == mode) return;
    _pickMode = mode;
    _focusedDriver = null;
    _safeNotify();
  }

  void updatePickupAddress(String value) {
    _pickupAddress = value;
  }

  void updateDropoffAddress(String value) {
    _dropoffAddress = value;
  }

  Future<void> onMapTapped(LatLng point, {String locale = 'ar'}) async {
    final isAr = locale.toLowerCase().startsWith('ar');
    _focusedDriver = null;
    if (_pickMode == MapPickMode.pickup) {
      _pickupPoint = point;
      _pickupAddress = formatCoordinateLabel(point, isArabic: isAr);
      // Automatically advance pick mode to dropoff when dropoff is not yet set.
      if (_dropoffPoint == null) {
        _pickMode = MapPickMode.dropoff;
      }
      _safeNotify();
      await Future.wait<void>(<Future<void>>[
        refreshNearbyDrivers(locale: locale),
        _reverseGeocodePickup(point, locale: locale),
        if (_dropoffPoint != null) refreshDrivingRoute(),
      ]);
    } else {
      _dropoffPoint = point;
      _dropoffAddress = formatCoordinateLabel(point, isArabic: isAr);
      _safeNotify();
      await Future.wait<void>(<Future<void>>[
        _reverseGeocodeDropoff(point, locale: locale),
        refreshDrivingRoute(),
      ]);
    }
  }

  /// Searches places using Nominatim via [MapAndQuoteRepository.searchPlaces].
  Future<List<GeoPlaceSuggestion>> searchPlaces(
    String query, {
    String locale = 'ar',
  }) async {
    final trimmed = query.trim();
    final seq = ++_searchSeq;
    if (trimmed.isEmpty) {
      _searchResults = const <GeoPlaceSuggestion>[];
      _isSearchingPlaces = false;
      _safeNotify();
      return _searchResults;
    }

    _isSearchingPlaces = true;
    _safeNotify();

    try {
      final results = await _mapRepository.searchPlaces(
        trimmed,
        locale: locale,
      );
      if (seq != _searchSeq || _disposed) return _searchResults;
      _searchResults = results;
      return results;
    } catch (_) {
      if (seq == _searchSeq && !_disposed) {
        _searchResults = const <GeoPlaceSuggestion>[];
      }
      return const <GeoPlaceSuggestion>[];
    } finally {
      if (seq == _searchSeq && !_disposed) {
        _isSearchingPlaces = false;
        _safeNotify();
      }
    }
  }

  void clearSearchResults() {
    _searchSeq++;
    _searchResults = const <GeoPlaceSuggestion>[];
    _isSearchingPlaces = false;
    _safeNotify();
  }

  /// Applies a selected place autocomplete suggestion as either pickup or
  /// dropoff, refreshing nearby winches and the OSRM driving route.
  Future<void> selectPlaceSuggestion(
    GeoPlaceSuggestion suggestion, {
    required MapPickMode target,
    String locale = 'ar',
  }) async {
    final point = LatLng(suggestion.lat, suggestion.lng);
    final label = suggestion.shortName.trim().isNotEmpty
        ? suggestion.shortName.trim()
        : suggestion.displayName.trim();

    _focusedDriver = null;
    _searchResults = const <GeoPlaceSuggestion>[];
    _isSearchingPlaces = false;

    if (target == MapPickMode.pickup) {
      _pickupGeocodeSeq++;
      _pickupPoint = point;
      _pickupAddress = label;
      if (_dropoffPoint == null) {
        _pickMode = MapPickMode.dropoff;
      }
      _safeNotify();
      await Future.wait<void>(<Future<void>>[
        refreshNearbyDrivers(locale: locale),
        if (_dropoffPoint != null) refreshDrivingRoute(),
      ]);
    } else {
      _dropoffGeocodeSeq++;
      _dropoffPoint = point;
      _dropoffAddress = label;
      _pickMode = MapPickMode.dropoff;
      _safeNotify();
      await refreshDrivingRoute();
    }
  }

  /// Fetches the driving route polyline & distance between pickup and dropoff.
  Future<void> refreshDrivingRoute() async {
    final dropoff = _dropoffPoint;
    if (dropoff == null) {
      _roadRoute = null;
      _isLoadingRoute = false;
      _safeNotify();
      return;
    }

    final seq = ++_routeSeq;
    _isLoadingRoute = true;
    _safeNotify();

    try {
      final result = await _mapRepository.getDrivingRoute(
        fromLat: _pickupPoint.latitude,
        fromLng: _pickupPoint.longitude,
        toLat: dropoff.latitude,
        toLng: dropoff.longitude,
      );
      if (seq != _routeSeq || _disposed) return;
      _roadRoute = result;
    } catch (_) {
      // Keep graceful straight-line fallback via routePolylinePoints.
    } finally {
      if (seq == _routeSeq && !_disposed) {
        _isLoadingRoute = false;
        _safeNotify();
      }
    }
  }

  Future<void> _reverseGeocodePickup(
    LatLng point, {
    required String locale,
  }) async {
    final seq = ++_pickupGeocodeSeq;
    _isReverseGeocoding = true;
    _safeNotify();
    try {
      final resolved = await _mapRepository.reverseGeocode(
        point.latitude,
        point.longitude,
        locale: locale,
      );
      if (seq != _pickupGeocodeSeq || _disposed) return;
      if (resolved != null && resolved.trim().isNotEmpty) {
        _pickupAddress = resolved.trim();
      }
    } catch (_) {
      // Keep coordinate label fallback smoothly when offline.
    } finally {
      if (seq == _pickupGeocodeSeq && !_disposed) {
        _isReverseGeocoding = false;
        _safeNotify();
      }
    }
  }

  Future<void> _reverseGeocodeDropoff(
    LatLng point, {
    required String locale,
  }) async {
    final seq = ++_dropoffGeocodeSeq;
    _isReverseGeocoding = true;
    _safeNotify();
    try {
      final resolved = await _mapRepository.reverseGeocode(
        point.latitude,
        point.longitude,
        locale: locale,
      );
      if (seq != _dropoffGeocodeSeq || _disposed) return;
      if (resolved != null && resolved.trim().isNotEmpty) {
        _dropoffAddress = resolved.trim();
      }
    } catch (_) {
      // Keep coordinate label fallback smoothly when offline.
    } finally {
      if (seq == _dropoffGeocodeSeq && !_disposed) {
        _isReverseGeocoding = false;
        _safeNotify();
      }
    }
  }

  Future<void> selectWinchType(WinchType type, {String locale = 'ar'}) async {
    if (_selectedWinchType?.id == type.id) return;
    _selectedWinchType = type;
    _focusedDriver = null;
    _safeNotify();
    await refreshNearbyDrivers(locale: locale);
  }

  void focusDriver(NearbyDriver? driver) {
    _focusedDriver = driver;
    _safeNotify();
  }

  Future<void> refreshNearbyDrivers({String locale = 'ar'}) async {
    final winchType = _selectedWinchType;
    if (winchType == null) return;

    _isLoadingDrivers = true;
    _safeNotify();

    try {
      _nearbyDrivers = await _mapRepository.findNearestDrivers(
        pickupLat: _pickupPoint.latitude,
        pickupLng: _pickupPoint.longitude,
        winchTypeId: winchType.id,
        radiusMeters: 20000,
        limit: 15,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoadingDrivers = false;
      _safeNotify();
    }
  }

  RouteSelection? buildRouteSelection() {
    final dropoff = _dropoffPoint;
    if (dropoff == null) return null;
    return RouteSelection(
      pickupPoint: _pickupPoint,
      pickupAddress: _pickupAddress.trim().isEmpty
          ? '${_pickupPoint.latitude.toStringAsFixed(4)}, ${_pickupPoint.longitude.toStringAsFixed(4)}'
          : _pickupAddress.trim(),
      dropoffPoint: dropoff,
      dropoffAddress: _dropoffAddress.trim().isEmpty
          ? '${dropoff.latitude.toStringAsFixed(4)}, ${dropoff.longitude.toStringAsFixed(4)}'
          : _dropoffAddress.trim(),
      initialWinchTypeId: _selectedWinchType?.id,
      routeDistanceKm: _roadRoute?.distanceKm,
      routeDurationMinutes: _roadRoute?.durationMinutes,
      routePolyline: routePolylinePoints,
    );
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
