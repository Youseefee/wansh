import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wenshy_core/wenshy_core.dart';

void main() {
  group('WenshyGeoService.searchPlaces', () {
    test('sends Nominatim headers/params and parses UTF-8 Arabic results', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        final body = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'display_name': 'شارع عباس العقاد، مدينة نصر، القاهرة، مصر',
            'name': 'شارع عباس العقاد',
            'lat': '30.0561',
            'lon': '31.3301',
            'address': <String, dynamic>{
              'road': 'شارع عباس العقاد',
              'suburb': 'مدينة نصر',
              'city': 'القاهرة',
            },
          },
          <String, dynamic>{
            'display_name': 'ميدان التحرير، وسط البلد، القاهرة، مصر',
            'lat': '30.0444',
            'lon': '31.2357',
          },
        ]);
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });

      final geo = WenshyGeoService(client: client);
      final results = await geo.searchPlaces(
        'عباس العقاد',
        locale: 'ar',
        countryCode: 'eg',
        limit: 5,
      );

      expect(captured.url.host, 'nominatim.openstreetmap.org');
      expect(captured.url.path, '/search');
      expect(captured.url.queryParameters['q'], 'عباس العقاد');
      expect(captured.url.queryParameters['countrycodes'], 'eg');
      expect(captured.url.queryParameters['limit'], '5');
      expect(captured.headers['User-Agent'], 'WenshyApp/1.0');
      expect(captured.headers['Accept-Language'], startsWith('ar'));

      expect(results, hasLength(2));
      expect(
        results.first,
        const GeoPlaceSuggestion(
          displayName: 'شارع عباس العقاد، مدينة نصر، القاهرة، مصر',
          shortName: 'شارع عباس العقاد، مدينة نصر، القاهرة',
          lat: 30.0561,
          lng: 31.3301,
        ),
      );
      expect(results[1].shortName, 'ميدان التحرير، وسط البلد');
    });

    test('returns empty list immediately for blank query without HTTP call', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('[]', 200);
      });

      final geo = WenshyGeoService(client: client);
      final results = await geo.searchPlaces('   ');

      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('degrades gracefully on HTTP error or socket exception', () async {
      final errorGeo = WenshyGeoService(
        client: MockClient((_) async => http.Response('Too Many Requests', 429)),
      );
      expect(await errorGeo.searchPlaces('Cairo', locale: 'en'), isEmpty);

      final offlineGeo = WenshyGeoService(
        client: MockClient((_) => throw const SocketException('Offline')),
      );
      expect(await offlineGeo.searchPlaces('Cairo', locale: 'en'), isEmpty);
    });
  });

  group('WenshyGeoService.reverseGeocode', () {
    test('returns clean Arabic and English labels from address details', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.path, '/reverse');
        expect(request.headers['User-Agent'], 'WenshyApp/1.0');

        final isArabic =
            (request.headers['Accept-Language'] ?? '').startsWith('ar');
        final payload = isArabic
            ? <String, dynamic>{
                'display_name': 'شارع التسعين، التجمع الخامس، القاهرة الجديدة، مصر',
                'address': <String, dynamic>{
                  'road': 'شارع التسعين',
                  'suburb': 'التجمع الخامس',
                  'city': 'القاهرة الجديدة',
                },
              }
            : <String, dynamic>{
                'display_name': '90th Street, Fifth Settlement, New Cairo, Egypt',
                'address': <String, dynamic>{
                  'road': '90th Street',
                  'suburb': 'Fifth Settlement',
                  'city': 'New Cairo',
                },
              };

        return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
      });

      final geo = WenshyGeoService(client: client);
      final arLabel = await geo.reverseGeocode(30.025, 31.471, locale: 'ar');
      final enLabel = await geo.reverseGeocode(30.025, 31.471, locale: 'en');

      expect(arLabel, 'شارع التسعين، التجمع الخامس، القاهرة الجديدة');
      expect(enLabel, '90th Street, Fifth Settlement, New Cairo');
    });

    test('returns null on Nominatim error payload or network failure', () async {
      final apiErrorGeo = WenshyGeoService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(const <String, dynamic>{'error': 'Unable to geocode'}),
            200,
          ),
        ),
      );
      expect(await apiErrorGeo.reverseGeocode(0, 0), isNull);

      final offlineGeo = WenshyGeoService(
        client: MockClient((_) => throw const SocketException('Offline')),
      );
      expect(await offlineGeo.reverseGeocode(30.0444, 31.2357), isNull);
    });
  });

  group('WenshyGeoService.getDrivingRoute', () {
    test('parses OSRM GeoJSON polyline converting [lng, lat] to (lat, lng)', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        final payload = <String, dynamic>{
          'code': 'Ok',
          'routes': <Map<String, dynamic>>[
            <String, dynamic>{
              'distance': 12450.0,
              'duration': 1140.0,
              'geometry': <String, dynamic>{
                'type': 'LineString',
                'coordinates': <List<double>>[
                  <double>[31.2357, 30.0444],
                  <double>[31.2800, 30.0650],
                  <double>[31.3292, 30.0875],
                ],
              },
            },
          ],
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final geo = WenshyGeoService(client: client);
      final route = await geo.getDrivingRoute(
        fromLat: 30.0444,
        fromLng: 31.2357,
        toLat: 30.0875,
        toLng: 31.3292,
      );

      expect(captured.url.host, 'router.project-osrm.org');
      expect(
        captured.url.path,
        '/route/v1/driving/31.2357,30.0444;31.3292,30.0875',
      );
      expect(captured.url.queryParameters['overview'], 'full');
      expect(captured.url.queryParameters['geometries'], 'geojson');

      expect(route.isFallback, isFalse);
      expect(route.distanceKm, 12.45);
      expect(route.durationMinutes, 19);
      expect(route.points, hasLength(3));
      expect(route.points.first, (lat: 30.0444, lng: 31.2357));
      expect(route.points[1], (lat: 30.0650, lng: 31.2800));
      expect(route.points.last, (lat: 30.0875, lng: 31.3292));
    });

    test('falls back to straight-line route on offline error or timeout', () async {
      final offlineGeo = WenshyGeoService(
        client: MockClient((_) => throw const SocketException('No internet')),
      );

      final route = await offlineGeo.getDrivingRoute(
        fromLat: 30.0444,
        fromLng: 31.2357,
        toLat: 30.0875,
        toLng: 31.3292,
      );

      expect(route.isFallback, isTrue);
      expect(route.points, const <({double lat, double lng})>[
        (lat: 30.0444, lng: 31.2357),
        (lat: 30.0875, lng: 31.3292),
      ]);
      expect(route.distanceKm, greaterThan(10.0));
      expect(route.durationMinutes, greaterThan(10));

      final timeoutGeo = WenshyGeoService(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('{}', 200);
        }),
      );
      final timedOut = await timeoutGeo.getDrivingRoute(
        fromLat: 30.0444,
        fromLng: 31.2357,
        toLat: 30.0875,
        toLng: 31.3292,
      );
      expect(timedOut.isFallback, isTrue);
      expect(timedOut.points, hasLength(2));
    });

    test('falls back when OSRM returns NoRoute or HTTP 503', () async {
      final noRouteGeo = WenshyGeoService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(const <String, dynamic>{
              'code': 'NoRoute',
              'routes': <dynamic>[],
            }),
            200,
          ),
        ),
      );
      final result = await noRouteGeo.getDrivingRoute(
        fromLat: 30.0,
        fromLng: 31.2,
        toLat: 30.1,
        toLng: 31.3,
      );
      expect(result.isFallback, isTrue);
      expect(result.points, hasLength(2));
    });

    test('RoadRouteResult supports value equality', () {
      const a = RoadRouteResult(
        points: <({double lat, double lng})>[
          (lat: 30.0, lng: 31.2),
          (lat: 30.1, lng: 31.3),
        ],
        distanceKm: 12.5,
        durationMinutes: 20,
        isFallback: false,
      );
      const b = RoadRouteResult(
        points: <({double lat, double lng})>[
          (lat: 30.0, lng: 31.2),
          (lat: 30.1, lng: 31.3),
        ],
        distanceKm: 12.5,
        durationMinutes: 20,
        isFallback: false,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
