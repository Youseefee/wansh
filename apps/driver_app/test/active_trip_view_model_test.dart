import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/data/services/external_launcher_service.dart';
import 'package:wenshy_driver/data/services/location_service.dart';
import 'package:wenshy_driver/ui/core/widgets/driver_widgets.dart';
import 'package:wenshy_driver/ui/features/trip/view_models/active_trip_view_model.dart';
import 'package:wenshy_driver/ui/features/trip/views/active_trip_view.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  group('ActiveTripViewModel', () {
    test(
        'progresses through all 5 driver stages until delivered and closes streaming',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final tripRepo = FakeDriverTripRepository()
        ..activeTrip = TestFixtures.rescueRequest(
          id: 'req-1',
          status: TripStatus.driverAssigned,
        );
      final geoService = FakeWenshyGeoService();
      final launcher = FakeDriverExternalLauncher();
      final deps = createTestDependencies(
        authRepository: authRepo,
        tripRepository: tripRepo,
        geoService: geoService,
        externalLauncher: launcher,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = ActiveTripViewModel(
        tripRepository: tripRepo,
        locationSource: deps.locationSource,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
        geoService: geoService,
        externalLauncher: launcher,
      );
      addTearDown(vm.dispose);

      await vm.loadTrip('req-1');
      expect(vm.isGpsStreaming, isTrue);
      expect(vm.nextStage, TripStatus.enRouteToPickup);

      const expectedStages = <TripStatus>[
        TripStatus.enRouteToPickup,
        TripStatus.arrivedAtPickup,
        TripStatus.vehicleLoaded,
        TripStatus.enRouteToDropoff,
        TripStatus.delivered,
      ];

      for (final stage in expectedStages) {
        expect(vm.nextStage, stage);
        final ok = await vm.advanceToNextStage();
        expect(ok, isTrue);
        expect(vm.trip?.status, stage);
      }

      expect(tripRepo.stageTransitions, expectedStages);
      expect(vm.nextStage, isNull);
      expect(vm.isGpsStreaming, isFalse);
      expect(deps.sessionController.activeTripId, isNull);
    });

    test(
        'broadcasts every GPS update to trip channel while throttling PostGIS DB sync to 20s',
        () async {
      var now = DateTime.utc(2026, 11, 12, 18, 0, 0);
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final tripRepo = FakeDriverTripRepository()
        ..activeTrip = TestFixtures.rescueRequest(
          id: 'req-gps',
          status: TripStatus.enRouteToPickup,
        );
      final locationSource = FakeDriverLocationSource();
      final geoService = FakeWenshyGeoService();
      final deps = createTestDependencies(
        authRepository: authRepo,
        tripRepository: tripRepo,
        locationSource: locationSource,
        geoService: geoService,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = ActiveTripViewModel(
        tripRepository: tripRepo,
        locationSource: locationSource,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
        geoService: geoService,
        externalLauncher: FakeDriverExternalLauncher(),
        clock: () => now,
        dbSyncInterval: const Duration(seconds: 20),
      );
      addTearDown(vm.dispose);

      await vm.loadTrip('req-gps');

      Future<void> emitPoint(double lat, double lng) async {
        locationSource.streamController.add(
          DriverPositionData(lat: lat, lng: lng, heading: 120, speedKmh: 55),
        );
        await Future<void>.delayed(Duration.zero);
      }

      // t = 0s -> broadcast #1, DB sync #1
      await emitPoint(30.050, 31.240);
      expect(vm.broadcastCount, 1);
      expect(vm.dbSyncCount, 1);

      // t = +5s -> broadcast #2, NO DB sync (< 20s)
      now = now.add(const Duration(seconds: 5));
      await emitPoint(30.052, 31.242);
      expect(vm.broadcastCount, 2);
      expect(vm.dbSyncCount, 1);

      // t = +15s -> broadcast #3, NO DB sync (< 20s since t=0)
      now = now.add(const Duration(seconds: 10));
      await emitPoint(30.054, 31.244);
      expect(vm.broadcastCount, 3);
      expect(vm.dbSyncCount, 1);

      // t = +20s -> broadcast #4, DB sync #2
      now = now.add(const Duration(seconds: 5));
      await emitPoint(30.056, 31.246);
      expect(vm.broadcastCount, 4);
      expect(vm.dbSyncCount, 2);

      // t = +41s -> broadcast #5, DB sync #3
      now = now.add(const Duration(seconds: 21));
      await emitPoint(30.058, 31.248);
      expect(vm.broadcastCount, 5);
      expect(vm.dbSyncCount, 3);
      expect(tripRepo.broadcastedPoints, hasLength(5));
      expect(tripRepo.dbSyncedPoints, hasLength(3));
    });

    test(
        'loads driver->pickup road polyline before vehicle_loaded and pickup->dropoff after vehicle_loaded',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final trip = TestFixtures.rescueRequest(
        id: 'req-route',
        status: TripStatus.driverAssigned,
      );
      final tripRepo = FakeDriverTripRepository()..activeTrip = trip;
      final geoService = FakeWenshyGeoService();
      final launcher = FakeDriverExternalLauncher();
      final deps = createTestDependencies(
        authRepository: authRepo,
        tripRepository: tripRepo,
        geoService: geoService,
        externalLauncher: launcher,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = deps.createActiveTripViewModel();
      addTearDown(vm.dispose);

      await vm.loadTrip('req-route');

      // Initial route before vehicle_loaded: driver cached coords (30.0444, 31.2357) -> pickup (30.05, 31.24)
      expect(geoService.routeRequests, hasLength(1));
      expect(geoService.routeRequests.first.fromLat, 30.0444);
      expect(geoService.routeRequests.first.fromLng, 31.2357);
      expect(geoService.routeRequests.first.toLat, trip.pickupLat);
      expect(geoService.routeRequests.first.toLng, trip.pickupLng);
      expect(vm.routePolylinePoints, hasLength(3));
      expect(vm.activeRoute?.distanceKm, 6.4);
      expect(vm.activeRoute?.durationMinutes, 14);
      expect(vm.isDropoffLeg, isFalse);

      // Advance to en_route_to_pickup & arrived_at_pickup -> still pickup leg
      await vm.advanceToNextStage(); // en_route_to_pickup
      await vm.advanceToNextStage(); // arrived_at_pickup
      expect(vm.isDropoffLeg, isFalse);

      // Advance to vehicle_loaded -> triggers pickup -> dropoff road polyline
      await vm.advanceToNextStage(); // vehicle_loaded
      expect(vm.isDropoffLeg, isTrue);
      expect(geoService.routeRequests.last.fromLat, trip.pickupLat);
      expect(geoService.routeRequests.last.fromLng, trip.pickupLng);
      expect(geoService.routeRequests.last.toLat, trip.dropoffLat);
      expect(geoService.routeRequests.last.toLng, trip.dropoffLng);
      expect(
        vm.routePolylinePoints.first,
        LatLng(trip.pickupLat, trip.pickupLng),
      );
      expect(
        vm.routePolylinePoints.last,
        LatLng(trip.dropoffLat, trip.dropoffLng),
      );
    });

    test('calls customer phone and opens external navigation for pickup vs dropoff',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final trip = TestFixtures.rescueRequest(
        id: 'req-nav',
        status: TripStatus.enRouteToPickup,
      );
      final tripRepo = FakeDriverTripRepository()..activeTrip = trip;
      final launcher = FakeDriverExternalLauncher();
      final deps = createTestDependencies(
        authRepository: authRepo,
        tripRepository: tripRepo,
        externalLauncher: launcher,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = deps.createActiveTripViewModel();
      addTearDown(vm.dispose);

      await vm.loadTrip('req-nav');

      // Call customer
      final called = await vm.callCustomer();
      expect(called, isTrue);
      expect(launcher.calledPhones, <String>['+201112223344']);

      // Navigate while en_route_to_pickup -> Pickup coordinates
      expect(vm.navigationTarget?.isDropoff, isFalse);
      final navPickup = await vm.openExternalNavigation(
        provider: ExternalNavProvider.googleMaps,
      );
      expect(navPickup, isTrue);
      expect(launcher.navigatedTargets.last.lat, trip.pickupLat);
      expect(launcher.navigatedTargets.last.lng, trip.pickupLng);
      expect(
        launcher.navigatedTargets.last.provider,
        ExternalNavProvider.googleMaps,
      );

      // Advance to arrived_at_pickup -> vehicle_loaded
      await vm.advanceToNextStage(); // arrived_at_pickup
      await vm.advanceToNextStage(); // vehicle_loaded
      expect(vm.navigationTarget?.isDropoff, isTrue);

      // Navigate while vehicle_loaded -> Dropoff coordinates via Waze
      final navDropoff = await vm.openExternalNavigation(
        provider: ExternalNavProvider.waze,
      );
      expect(navDropoff, isTrue);
      expect(launcher.navigatedTargets.last.lat, trip.dropoffLat);
      expect(launcher.navigatedTargets.last.lng, trip.dropoffLng);
      expect(launcher.navigatedTargets.last.provider, ExternalNavProvider.waze);
    });
  });

  group('External Navigation URIs & Background Location Settings', () {
    test('builds Android google.navigation URI with HTTPS fallback and Waze URI',
        () {
      final androidMaps = UrlLauncherDriverExternalLauncher.buildNavigationUris(
        lat: 30.05,
        lng: 31.24,
        provider: ExternalNavProvider.googleMaps,
        platform: TargetPlatform.android,
      );
      expect(androidMaps, hasLength(2));
      expect(androidMaps.first.toString(), 'google.navigation:q=30.05,31.24');
      expect(
        androidMaps.last.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=30.05,31.24',
      );

      final waze = UrlLauncherDriverExternalLauncher.buildNavigationUris(
        lat: 30.09,
        lng: 31.33,
        provider: ExternalNavProvider.waze,
        platform: TargetPlatform.android,
      );
      expect(waze.first.toString(), 'waze://?ll=30.09,31.33&navigate=yes');
      expect(
        waze.last.toString(),
        'https://waze.com/ul?ll=30.09,31.33&navigate=yes',
      );

      final tel = UrlLauncherDriverExternalLauncher.buildPhoneUri(
        '+20 111-222-3344',
      );
      expect(tel.toString(), 'tel:+201112223344');
    });

    test(
        'configures Android foreground notification service and iOS background location updates',
        () {
      final androidSettings =
          GeolocatorDriverLocationSource.buildPositionStreamSettings(
        platform: TargetPlatform.android,
      );
      expect(androidSettings, isA<AndroidSettings>());
      final android = androidSettings as AndroidSettings;
      final fg = android.foregroundNotificationConfig;
      expect(fg, isNotNull);
      expect(fg!.enableWakeLock, isTrue);
      expect(fg.setOngoing, isTrue);
      expect(fg.notificationTitle, contains('Wenshy'));
      expect(fg.notificationText, contains('ونشي').or(contains('موقعك')));

      final iosSettings =
          GeolocatorDriverLocationSource.buildPositionStreamSettings(
        platform: TargetPlatform.iOS,
      );
      expect(iosSettings, isA<AppleSettings>());
      final apple = iosSettings as AppleSettings;
      expect(apple.allowBackgroundLocationUpdates, isTrue);
      expect(apple.pauseLocationUpdatesAutomatically, isFalse);
      expect(apple.showBackgroundLocationIndicator, isTrue);
    });
  });

  group('ActiveTripView widget', () {
    testWidgets(
        'renders road polyline, Call Customer button, and Navigate buttons',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final tripRepo = FakeDriverTripRepository()
        ..activeTrip = TestFixtures.rescueRequest(
          id: 'req-widget',
          status: TripStatus.driverAssigned,
        );
      final launcher = FakeDriverExternalLauncher();
      final deps = createTestDependencies(
        authRepository: authRepo,
        tripRepository: tripRepo,
        externalLauncher: launcher,
      );
      await deps.sessionController.initialize();
      final vm = deps.createActiveTripViewModel();
      addTearDown(() {
        vm.dispose();
        deps.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ActiveTripView(
              requestId: 'req-widget',
              viewModel: vm,
              localeController: deps.localeController,
              showMapTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapWidget = tester.widget<DriverRouteMap>(
        find.byType(DriverRouteMap),
      );
      expect(mapWidget.routePoints, isNotNull);
      expect(mapWidget.routePoints!.length, 3);

      // Tap Navigate (Google Maps)
      final navBtn = find.byKey(const Key('navigate_google_maps_btn'));
      await tester.dragUntilVisible(
        navBtn,
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(navBtn);
      await tester.pump();
      expect(launcher.navigatedTargets, hasLength(1));
      expect(launcher.navigatedTargets.first.lat, 30.05);

      // Tap Call Customer
      final callBtn = find.byKey(const Key('call_customer_btn'));
      await tester.dragUntilVisible(
        callBtn,
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(callBtn);
      await tester.pump();
      expect(launcher.calledPhones, <String>['+201112223344']);
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
