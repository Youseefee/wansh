import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Abstracts GPS position retrieval so map viewmodels can be tested cleanly.
abstract class LocationDataSource {
  Future<LatLng?> getCurrentLocation();
}

/// Device GPS implementation powered by `geolocator`.
class GeolocatorDataSource implements LocationDataSource {
  const GeolocatorDataSource();

  @override
  Future<LatLng?> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

/// Repository for tow-truck catalog browsing, nearby driver lookup,
/// server quotations, geocoding/routing, and GPS location detection.
abstract class MapAndQuoteRepository {
  Future<LatLng?> getCurrentLocation();
  Future<List<WinchType>> getActiveWinchTypes();
  Future<List<NearbyDriver>> findNearestDrivers({
    required double pickupLat,
    required double pickupLng,
    required String winchTypeId,
    int radiusMeters = 15000,
    int limit = 10,
  });
  Future<WinchQuote> calculateQuote({
    required String winchTypeId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? routeDistanceKm,
  });
  Future<List<GeoPlaceSuggestion>> searchPlaces(
    String query, {
    String locale = 'ar',
    String countryCode = 'eg',
    int limit = 5,
  });
  Future<String?> reverseGeocode(
    double lat,
    double lng, {
    String locale = 'ar',
  });
  Future<RoadRouteResult> getDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  });
}

/// Supabase + Geolocator + WenshyGeoService implementation of
/// [MapAndQuoteRepository].
class SupabaseMapAndQuoteRepository implements MapAndQuoteRepository {
  SupabaseMapAndQuoteRepository({
    WinchCatalogService? catalogService,
    LocationDataSource? locationDataSource,
    WenshyGeoService? geoService,
  })  : _catalog = catalogService ?? const WinchCatalogService(),
        _location = locationDataSource ?? const GeolocatorDataSource(),
        _geo = geoService ?? const WenshyGeoService();

  final WinchCatalogService _catalog;
  final LocationDataSource _location;
  final WenshyGeoService _geo;

  @override
  Future<LatLng?> getCurrentLocation() => _location.getCurrentLocation();

  @override
  Future<List<WinchType>> getActiveWinchTypes() =>
      _catalog.getActiveWinchTypes();

  @override
  Future<List<NearbyDriver>> findNearestDrivers({
    required double pickupLat,
    required double pickupLng,
    required String winchTypeId,
    int radiusMeters = 15000,
    int limit = 10,
  }) =>
      _catalog.findNearestDrivers(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        winchTypeId: winchTypeId,
        radiusMeters: radiusMeters,
        limit: limit,
      );

  @override
  Future<WinchQuote> calculateQuote({
    required String winchTypeId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? routeDistanceKm,
  }) =>
      _catalog.calculateQuote(
        winchTypeId: winchTypeId,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        routeDistanceKm: routeDistanceKm,
      );

  @override
  Future<List<GeoPlaceSuggestion>> searchPlaces(
    String query, {
    String locale = 'ar',
    String countryCode = 'eg',
    int limit = 5,
  }) =>
      _geo.searchPlaces(
        query,
        locale: locale,
        countryCode: countryCode,
        limit: limit,
      );

  @override
  Future<String?> reverseGeocode(
    double lat,
    double lng, {
    String locale = 'ar',
  }) =>
      _geo.reverseGeocode(lat, lng, locale: locale);

  @override
  Future<RoadRouteResult> getDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) =>
      _geo.getDrivingRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
}
