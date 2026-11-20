import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/wenshy_labels.dart';
import '../models/json_parsers.dart';

/// A geocoded place suggestion returned by [WenshyGeoService.searchPlaces].
@immutable
class GeoPlaceSuggestion {
  const GeoPlaceSuggestion({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });

  /// Full formatted address returned by Nominatim.
  final String displayName;

  /// Concise street/district label suitable for list subtitles and chips.
  final String shortName;

  /// WGS-84 latitude.
  final double lat;

  /// WGS-84 longitude.
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPlaceSuggestion &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName &&
          shortName == other.shortName &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => Object.hash(displayName, shortName, lat, lng);

  @override
  String toString() =>
      'GeoPlaceSuggestion(shortName: $shortName, lat: $lat, lng: $lng)';
}

/// A driving route polyline and summary returned by
/// [WenshyGeoService.getDrivingRoute].
@immutable
class RoadRouteResult {
  const RoadRouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.isFallback = false,
  });

  /// Ordered route coordinates as `(lat, lng)` records.
  final List<({double lat, double lng})> points;

  /// Driving distance in kilometers.
  final double distanceKm;

  /// Estimated driving duration in whole minutes.
  final int durationMinutes;

  /// `true` when OSRM was unreachable or returned no route and a straight-line
  /// fallback was generated instead.
  final bool isFallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadRouteResult &&
          runtimeType == other.runtimeType &&
          listEquals(points, other.points) &&
          distanceKm == other.distanceKm &&
          durationMinutes == other.durationMinutes &&
          isFallback == other.isFallback;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(points),
        distanceKm,
        durationMinutes,
        isFallback,
      );

  @override
  String toString() =>
      'RoadRouteResult(points: ${points.length}, distanceKm: $distanceKm, '
      'durationMinutes: $durationMinutes, isFallback: $isFallback)';
}

/// Geocoding (OpenStreetMap Nominatim) and driving road routing (OSRM) service.
///
/// Accepts an injectable [http.Client] for deterministic unit testing and
/// degrades gracefully on network errors or timeouts so the UI never crashes
/// offline.
class WenshyGeoService {
  const WenshyGeoService({
    this.client,
    this.timeout = const Duration(seconds: 8),
    this.userAgent = defaultUserAgent,
  });

  /// Default HTTP `User-Agent` required by Nominatim usage policy.
  static const String defaultUserAgent = 'WenshyApp/1.0';

  /// Optional injected HTTP client (caller manages lifecycle when provided).
  final http.Client? client;

  /// Per-request network timeout.
  final Duration timeout;

  /// HTTP `User-Agent` header value.
  final String userAgent;

  /// Searches places using OpenStreetMap Nominatim `/search`.
  ///
  /// Returns an empty list on blank query, network error, timeout, or invalid
  /// server response.
  Future<List<GeoPlaceSuggestion>> searchPlaces(
    String query, {
    String locale = 'ar',
    String countryCode = 'eg',
    int limit = 5,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return const <GeoPlaceSuggestion>[];

    final params = <String, String>{
      'q': trimmedQuery,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': limit.clamp(1, 20).toString(),
      if (countryCode.trim().isNotEmpty)
        'countrycodes': countryCode.trim().toLowerCase(),
    };

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);

    try {
      final response = await _get(
        uri,
        headers: _headers(locale: locale),
      );
      if (response.statusCode != 200) return const <GeoPlaceSuggestion>[];

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return const <GeoPlaceSuggestion>[];

      final suggestions = <GeoPlaceSuggestion>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final lat = JsonParsers.asNullableDouble(map['lat']);
        final lng = JsonParsers.asNullableDouble(map['lon']);
        final displayName = (map['display_name'] as String?)?.trim() ?? '';
        if (lat == null || lng == null || displayName.isEmpty) continue;

        final shortName = _extractShortName(
          map,
          displayName: displayName,
          locale: locale,
        );
        suggestions.add(
          GeoPlaceSuggestion(
            displayName: displayName,
            shortName: shortName,
            lat: lat,
            lng: lng,
          ),
        );
      }

      return List<GeoPlaceSuggestion>.unmodifiable(suggestions);
    } catch (_) {
      return const <GeoPlaceSuggestion>[];
    }
  }

  /// Reverse-geocodes [lat], [lng] using OpenStreetMap Nominatim `/reverse`.
  ///
  /// Returns a concise Arabic or English street/district label, or `null` on
  /// network error, timeout, or unresolvable coordinates.
  Future<String?> reverseGeocode(
    double lat,
    double lng, {
    String locale = 'ar',
  }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      <String, String>{
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
      },
    );

    try {
      final response = await _get(
        uri,
        headers: _headers(locale: locale),
      );
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map.containsKey('error')) return null;

      final displayName = (map['display_name'] as String?)?.trim() ?? '';
      final label = _extractShortName(
        map,
        displayName: displayName,
        locale: locale,
      );
      return label.isEmpty ? null : label;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a driving route polyline, road distance, and ETA from OSRM.
  ///
  /// Falls back gracefully to a two-point straight-line route with
  /// [RoadRouteResult.isFallback] set to `true` on any network error, timeout,
  /// or invalid OSRM response.
  Future<RoadRouteResult> getDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final path = '/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat';
    final uri = Uri.https(
      'router.project-osrm.org',
      path,
      const <String, String>{
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    try {
      final response = await _get(
        uri,
        headers: <String, String>{
          'User-Agent': userAgent,
          'Accept': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
      }

      final code = decoded['code'] as String?;
      final routes = decoded['routes'];
      if (code != 'Ok' || routes is! List || routes.isEmpty) {
        return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
      }

      final firstRoute = routes.first;
      if (firstRoute is! Map) {
        return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
      }

      final routeMap = Map<String, dynamic>.from(firstRoute);
      final geometry = routeMap['geometry'];
      final coords = geometry is Map ? geometry['coordinates'] : null;
      if (coords is! List || coords.length < 2) {
        return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
      }

      final points = <({double lat, double lng})>[];
      for (final coord in coords) {
        if (coord is! List || coord.length < 2) continue;
        final lng = JsonParsers.asNullableDouble(coord[0]);
        final lat = JsonParsers.asNullableDouble(coord[1]);
        if (lat == null || lng == null) continue;
        points.add((lat: lat, lng: lng));
      }

      if (points.length < 2) {
        return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
      }

      final distanceMeters =
          JsonParsers.asNullableDouble(routeMap['distance']) ?? 0.0;
      final durationSeconds =
          JsonParsers.asNullableDouble(routeMap['duration']) ?? 0.0;

      final distanceKm = _round2(distanceMeters / 1000.0);
      final durationMinutes = durationSeconds <= 0
          ? (distanceKm > 0 ? 1 : 0)
          : math.max(1, (durationSeconds / 60.0).round());

      return RoadRouteResult(
        points: List<({double lat, double lng})>.unmodifiable(points),
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        isFallback: false,
      );
    } catch (_) {
      return _buildFallbackRoute(fromLat, fromLng, toLat, toLng);
    }
  }

  /// Great-circle Haversine distance in kilometers between two WGS-84 points.
  static double haversineDistanceKm(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(toLat - fromLat);
    final dLng = _toRadians(toLng - fromLng);
    final lat1 = _toRadians(fromLat);
    final lat2 = _toRadians(toLat);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  Future<http.Response> _get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final injected = client;
    if (injected != null) {
      return injected.get(uri, headers: headers).timeout(timeout);
    }
    final localClient = http.Client();
    try {
      return await localClient.get(uri, headers: headers).timeout(timeout);
    } finally {
      localClient.close();
    }
  }

  Map<String, String> _headers({required String locale}) {
    final acceptLang =
        WenshyLabels.isArabic(locale) ? 'ar,en;q=0.8' : 'en,ar;q=0.8';
    return <String, String>{
      'User-Agent': userAgent,
      'Accept': 'application/json',
      'Accept-Language': acceptLang,
    };
  }

  static String _extractShortName(
    Map<String, dynamic> map, {
    required String displayName,
    required String locale,
  }) {
    final separator = WenshyLabels.isArabic(locale) ? '، ' : ', ';
    final parts = <String>[];

    void addPart(Object? value) {
      if (value is! String) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (!parts.contains(trimmed)) {
        parts.add(trimmed);
      }
    }

    final address = map['address'];
    if (address is Map) {
      final addr = Map<String, dynamic>.from(address);
      addPart(
        addr['road'] ??
            addr['pedestrian'] ??
            addr['amenity'] ??
            addr['building'] ??
            map['name'],
      );
      addPart(
        addr['neighbourhood'] ??
            addr['suburb'] ??
            addr['quarter'] ??
            addr['city_district'],
      );
      addPart(
        addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'],
      );
    } else {
      addPart(map['name']);
    }

    if (parts.isNotEmpty) {
      return parts.take(3).join(separator);
    }

    if (displayName.isEmpty) return '';
    final segments = displayName
        .split(RegExp(r'[,،]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(2)
        .toList();
    return segments.isEmpty ? displayName : segments.join(separator);
  }

  static RoadRouteResult _buildFallbackRoute(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    final geodesicKm = haversineDistanceKm(fromLat, fromLng, toLat, toLng);
    final estimatedKm = _round2(geodesicKm * 1.25);
    final estimatedMinutes = estimatedKm <= 0
        ? 0
        : math.max(1, (estimatedKm / 35.0 * 60.0).round());

    return RoadRouteResult(
      points: List<({double lat, double lng})>.unmodifiable(
        <({double lat, double lng})>[
          (lat: fromLat, lng: fromLng),
          (lat: toLat, lng: toLng),
        ],
      ),
      distanceKm: estimatedKm,
      durationMinutes: estimatedMinutes,
      isFallback: true,
    );
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  static double _round2(double value) => (value * 100).round() / 100;
}
