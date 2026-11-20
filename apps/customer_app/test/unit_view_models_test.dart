import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'package:wenshy_customer/data/repositories/models.dart';
import 'package:wenshy_customer/data/repositories/rescue_request_repository.dart';
import 'package:wenshy_customer/ui/core/locale_controller.dart';
import 'package:wenshy_customer/ui/core/push_token_service.dart';
import 'package:wenshy_customer/ui/features/auth/view_models/auth_view_model.dart';
import 'package:wenshy_customer/ui/features/feedback/view_models/complaints_view_model.dart';
import 'package:wenshy_customer/ui/features/feedback/view_models/rate_trip_view_model.dart';
import 'package:wenshy_customer/ui/features/home_map/view_models/home_map_view_model.dart';
import 'package:wenshy_customer/ui/features/live_trip/view_models/live_trip_view_model.dart';
import 'package:wenshy_customer/ui/features/notifications/view_models/notifications_view_model.dart';
import 'package:wenshy_customer/ui/features/request_rescue/view_models/request_rescue_view_model.dart';
import 'package:wenshy_customer/ui/features/trips_history/view_models/trips_history_view_model.dart';
import 'package:wenshy_customer/ui/features/vehicles/view_models/vehicles_view_model.dart';

import 'fakes/fake_repositories.dart';

void main() {
  group('LocaleController', () {
    test('defaults to Arabic RTL and toggles between ar and en', () {
      final controller = LocaleController();
      expect(controller.locale, const Locale('ar'));
      expect(controller.isArabic, isTrue);

      controller.toggleLocale();
      expect(controller.locale, const Locale('en'));
      expect(controller.isArabic, isFalse);

      controller.toggleLocale();
      expect(controller.locale, const Locale('ar'));
      controller.dispose();
    });
  });

  group('RescueRequestRealtimeParser', () {
    test('parses nested realtime.broadcast_changes payload', () {
      final raw = <String, dynamic>{
        'event': 'UPDATE',
        'payload': <String, dynamic>{
          'record': TestFixtures.makeRescueRequest(
            status: 'en_route_to_pickup',
            driverId: 'drv-1',
            winchId: 'winch-1',
          ).toJson(),
        },
      };

      final parsed = RescueRequestRealtimeParser.parseRescueRequestUpdate(raw);
      expect(parsed, isNotNull);
      expect(parsed!.status, TripStatus.enRouteToPickup);
      expect(parsed.driverId, 'drv-1');
    });

    test('parses direct driver_location broadcast and ignores invalid', () {
      final point = RescueRequestRealtimeParser.parseDriverLocation(
        <String, dynamic>{
          'lat': 30.0512,
          'lng': 31.2398,
          'heading': 135.0,
          'speed_kmh': 40.0,
          'recorded_at': TestFixtures.now.toIso8601String(),
        },
      );
      expect(point, isNotNull);
      expect(point!.lat, 30.0512);
      expect(point.heading, 135.0);

      expect(
        RescueRequestRealtimeParser.parseDriverLocation(<String, dynamic>{}),
        isNull,
      );
    });
  });

  group('HomeMapViewModel', () {
    test('initializes with GPS location, loads winches & builds route', () async {
      final mapRepo = FakeMapAndQuoteRepository();
      final rescueRepo = FakeRescueRequestRepository();
      final vm = HomeMapViewModel(
        mapRepository: mapRepo,
        rescueRepository: rescueRepo,
      );

      await vm.initialize(customerId: 'cust-1', locale: 'ar');

      expect(vm.locationFallbackUsed, isFalse);
      expect(vm.pickupPoint, const LatLng(30.0550, 31.2450));
      expect(vm.winchTypes.length, 2);
      expect(vm.selectedWinchType?.id, 'wt-flatbed');
      expect(vm.nearbyDrivers.length, 1);
      expect(vm.activeTrip?.id, 'req-1');

      expect(vm.buildRouteSelection(), isNull);

      vm.setPickMode(MapPickMode.dropoff);
      await vm.onMapTapped(const LatLng(30.0700, 31.2600), locale: 'ar');

      final selection = vm.buildRouteSelection();
      expect(selection, isNotNull);
      expect(selection!.dropoffPoint, const LatLng(30.0700, 31.2600));
      expect(selection.initialWinchTypeId, 'wt-flatbed');

      vm.dispose();
    });

    test('falls back to Cairo coordinates when GPS is unavailable', () async {
      final mapRepo = FakeMapAndQuoteRepository()..gpsLocation = null;
      final rescueRepo = FakeRescueRequestRepository();
      final vm = HomeMapViewModel(
        mapRepository: mapRepo,
        rescueRepository: rescueRepo,
      );

      await vm.initialize(customerId: 'cust-1', locale: 'en');
      expect(vm.locationFallbackUsed, isTrue);
      expect(vm.pickupPoint, kDefaultCairoLatLng);
      vm.dispose();
    });

    test('reverse-geocodes pickup/dropoff, searches places, fetches road route & falls back offline', () async {
      final mapRepo = FakeMapAndQuoteRepository();
      final rescueRepo = FakeRescueRequestRepository();
      final vm = HomeMapViewModel(
        mapRepository: mapRepo,
        rescueRepository: rescueRepo,
      );

      await vm.initialize(customerId: 'cust-1', locale: 'ar');
      expect(vm.pickupAddress, 'شارع التحرير، الدقي، الجيزة');
      expect(mapRepo.reverseGeocodeCalls, 1);

      // Search places & select dropoff suggestion -> triggers OSRM route fetch
      final suggestions = await vm.searchPlaces('مدينة نصر', locale: 'ar');
      expect(mapRepo.lastSearchQuery, 'مدينة نصر');
      expect(suggestions.length, 2);

      await vm.selectPlaceSuggestion(
        suggestions[1],
        target: MapPickMode.dropoff,
        locale: 'ar',
      );
      expect(vm.dropoffAddress, 'عباس العقاد، مدينة نصر');
      expect(vm.routePolylinePoints.length, 3);
      expect(vm.routeDistanceKm, 12.4);
      expect(vm.routeDurationMinutes, 24);

      final selection = vm.buildRouteSelection()!;
      expect(selection.routeDistanceKm, 12.4);
      expect(selection.routeDurationMinutes, 24);
      expect(selection.routePolyline.length, 3);

      // Offline reverse-geocode returns null -> falls back to formatted coordinates
      mapRepo.reverseGeocodeLabel = null;
      vm.setPickMode(MapPickMode.pickup);
      await vm.onMapTapped(const LatLng(30.1111, 31.2222), locale: 'en');
      expect(vm.pickupAddress, contains('30.1111'));
      expect(vm.pickupAddress, contains('31.2222'));

      vm.dispose();
    });
  });

  group('RequestRescueViewModel', () {
    test('refreshes quote on winch switch & uploads photos after create', () async {
      final mapRepo = FakeMapAndQuoteRepository();
      final vehicleRepo = FakeVehicleRepository();
      final rescueRepo = FakeRescueRequestRepository();

      final vm = RequestRescueViewModel(
        route: const RouteSelection(
          pickupPoint: LatLng(30.0444, 31.2357),
          pickupAddress: 'Tahrir',
          dropoffPoint: LatLng(30.0626, 31.2497),
          dropoffAddress: 'Nasr City',
          routeDistanceKm: 12.4,
          routeDurationMinutes: 24,
        ),
        mapRepository: mapRepo,
        vehicleRepository: vehicleRepo,
        rescueRepository: rescueRepo,
      );

      await vm.initialize(customerId: 'cust-1', locale: 'ar');
      expect(vm.errorMessage, isNull);
      expect(vm.savedVehicles.length, 1);
      expect(vm.selectedVehicle?.id, 'veh-1');
      expect(vm.quote?.estimatedPrice, 470.0);
      expect(mapRepo.lastQuoteRouteDistanceKm, 12.4);

      final wheelLift = mapRepo.winchTypes[1];
      await vm.selectWinchType(wheelLift, locale: 'ar');
      expect(vm.quote?.estimatedPrice, 360.0);

      vm.addPhotos(<SelectedPhotoBytes>[
        TestFixtures.makeSamplePhoto(name: 'front.jpg'),
      ]);

      final result = await vm.submitRequest(customerId: 'cust-1', locale: 'ar');
      expect(result, isNotNull);
      expect(rescueRepo.lastCreatedRouteDistanceKm, 12.4);
      expect(
        rescueRepo.callLog,
        <String>[
          'createRescueRequest',
          'uploadAndAttachBreakdownPhotos:req-1',
        ],
      );
      expect(
        result!.request.breakdownPhotoPaths,
        <String>['cust-1/req-1/front.jpg'],
      );
      vm.dispose();
    });
  });

  group('LiveTripViewModel', () {
    test('subscribes to trip channel, loads road route, animates location, retries wave 2, cancels', () async {
      final rescueRepo = FakeRescueRequestRepository();
      final mapRepo = FakeMapAndQuoteRepository();
      final vm = LiveTripViewModel(
        requestId: 'req-1',
        rescueRepository: rescueRepo,
        mapRepository: mapRepo,
        winchCatalog: const FakeWinchCatalogService(),
        initialRequest: TestFixtures.makeRescueRequest(),
        initialDispatch: TestFixtures.makeDispatchResult(),
      );

      await vm.initialize(locale: 'ar');
      expect(vm.realtimeConnected, isTrue);
      expect(rescueRepo.activeSubscription, isNotNull);
      expect(mapRepo.drivingRouteCalls, 1);
      expect(vm.routePolyline.length, 3);

      final wave2 = await vm.retryNextWave(locale: 'ar');
      expect(wave2, isNotNull);
      expect(wave2!.dispatchedCount, 2);
      expect(vm.request!.currentWave, 2);

      // Simulate incoming driver assignment & GPS update via Realtime
      final assignedReq = TestFixtures.makeRescueRequest(
        status: 'driver_assigned',
        driverId: 'drv-1',
        winchId: 'winch-1',
      );
      rescueRepo.activeSubscription!.onTripUpdate(assignedReq, <String, dynamic>{});
      await Future<void>.delayed(Duration.zero);
      expect(vm.request!.status, TripStatus.driverAssigned);
      expect(vm.driver?.profile?.fullName, 'كابتن كريم محمود');
      expect(vm.winch?.plateNumber, 'س ط 1234');

      rescueRepo.activeSubscription!.onDriverLocation(
        TestFixtures.makeLocationPoint(lat: 30.0599, lng: 31.2455),
      );
      expect(vm.driverLatLng, const LatLng(30.0599, 31.2455));

      final cancelled = await vm.cancelTrip(reason: 'تم حل المشكلة');
      expect(cancelled, isTrue);
      expect(vm.request!.status, TripStatus.cancelled);

      vm.dispose();
      expect(rescueRepo.activeSubscription!.disposed, isTrue);
    });
  });

  group('Vehicles, History, Ratings & Complaints ViewModels', () {
    test('VehiclesViewModel handles CRUD and default switching', () async {
      final repo = FakeVehicleRepository();
      final vm = VehiclesViewModel(repository: repo);

      await vm.loadVehicles('cust-1');
      expect(vm.vehicles.length, 1);
      expect(vm.vehicles.first.isDefault, isTrue);

      final ok = await vm.saveVehicle(
        customerId: 'cust-1',
        make: 'هيونداي',
        model: 'توسان',
        plateNumber: 'ن ه و 999',
        category: VehicleCategory.suv,
        isDefault: true,
      );
      expect(ok, isTrue);
      expect(vm.vehicles.length, 2);
      expect(vm.vehicles.where((v) => v.isDefault).length, 1);
      expect(vm.vehicles.first.make, 'هيونداي');

      await vm.deleteVehicle(
        customerId: 'cust-1',
        vehicleId: vm.vehicles.last.id,
      );
      expect(vm.vehicles.length, 1);
      vm.dispose();
    });

    test('TripsHistoryViewModel filters trips accurately', () async {
      final rescueRepo = FakeRescueRequestRepository();
      rescueRepo.requestsById['req-2'] = TestFixtures.makeRescueRequest(
        id: 'req-2',
        requestCode: 'WNS-1002',
        status: 'delivered',
      );
      rescueRepo.requestsById['req-3'] = TestFixtures.makeRescueRequest(
        id: 'req-3',
        requestCode: 'WNS-1003',
        status: 'cancelled',
      );

      final vm = TripsHistoryViewModel(repository: rescueRepo);
      await vm.loadTrips('cust-1');
      expect(vm.allTrips.length, 3);

      vm.setFilter(TripHistoryFilter.active);
      expect(vm.filteredTrips.map((t) => t.id), <String>['req-1']);

      vm.setFilter(TripHistoryFilter.completed);
      expect(vm.filteredTrips.map((t) => t.id), <String>['req-2']);

      vm.setFilter(TripHistoryFilter.cancelled);
      expect(vm.filteredTrips.map((t) => t.id), <String>['req-3']);
      vm.dispose();
    });

    test('RateTripViewModel and ComplaintsViewModel submit data', () async {
      final rescueRepo = FakeRescueRequestRepository();
      rescueRepo.requestsById['req-1'] = TestFixtures.makeRescueRequest(
        status: 'delivered',
        driverId: 'drv-1',
        winchId: 'winch-1',
      );
      final feedbackRepo = FakeFeedbackRepository();

      final rateVm = RateTripViewModel(
        requestId: 'req-1',
        rescueRepository: rescueRepo,
        feedbackRepository: feedbackRepo,
      );
      await rateVm.initialize();
      rateVm.setScore(4);
      rateVm.toggleTag('سرعة الوصول');
      rateVm.setComment('وصل بسرعة');
      final rating = await rateVm.submit(customerId: 'cust-1');
      expect(rating, isNotNull);
      expect(rating!.score, 4);
      expect(rating.tags, contains('سرعة الوصول'));
      rateVm.dispose();

      final complaintsVm = ComplaintsViewModel(repository: feedbackRepo);
      await complaintsVm.loadComplaints('cust-1');
      expect(complaintsVm.complaints.length, 1);

      complaintsVm.addEvidenceFiles(<SelectedPhotoBytes>[
        TestFixtures.makeSamplePhoto(name: 'e1.jpg'),
        TestFixtures.makeSamplePhoto(name: 'e2.jpg'),
        TestFixtures.makeSamplePhoto(name: 'e3.jpg'),
        TestFixtures.makeSamplePhoto(name: 'e4.jpg'),
        TestFixtures.makeSamplePhoto(name: 'e5.jpg'),
      ]);
      expect(complaintsVm.evidenceFiles.length, 4);

      final createdComplaint = await complaintsVm.submitComplaint(
        reporterId: 'cust-1',
        requestId: 'req-1',
        reportedUserId: 'drv-1',
        subject: 'مشكلة تسعير',
        description: 'طلب مبلغاً إضافياً',
      );
      expect(createdComplaint, isNotNull);
      expect(complaintsVm.complaints.length, 2);
      expect(complaintsVm.evidenceFiles, isEmpty);
      complaintsVm.dispose();
    });
  });

  group('AuthViewModel & PushTokenRegistrar', () {
    test('handles forgot password, phone OTP login, push token hook, and account deletion', () async {
      final authRepo = FakeAuthRepository(initiallySignedIn: false);
      final notifRepo = FakeNotificationRepository();
      final tokenProvider = FakePushTokenProvider(token: 'fcm-abc-999');
      final registrar = PushTokenRegistrar(
        notificationRepository: notifRepo,
        tokenProvider: tokenProvider,
      );
      final locale = LocaleController();
      final vm = AuthViewModel(
        repository: authRepo,
        localeController: locale,
        pushTokenRegistrar: registrar,
        autoListen: true,
      );

      // Forgot password
      final resetOk = await vm.sendPasswordResetEmail('sara@wenshy.app');
      expect(resetOk, isTrue);
      expect(authRepo.lastPasswordResetEmail, 'sara@wenshy.app');
      expect(vm.infoMessage, isNotNull);

      // Phone OTP send + verify
      final sent = await vm.sendPhoneOtp('+201001112233');
      expect(sent, isTrue);
      expect(vm.isAwaitingOtpVerification, isTrue);
      expect(authRepo.lastOtpPhone, '+201001112233');

      final verified = await vm.verifyPhoneOtp(
        phone: '+201001112233',
        token: '123456',
      );
      expect(verified, isTrue);
      expect(vm.isAuthenticated, isTrue);
      expect(authRepo.lastVerifiedOtpToken, '123456');
      expect(notifRepo.upsertedTokens, isNotEmpty);
      expect(notifRepo.upsertedTokens.last.token, 'fcm-abc-999');

      // Delete account blocked by active trip -> friendly error
      authRepo.deleteAccountError =
          Exception('P0001: Cannot delete account with active trip');
      final blocked = await vm.deleteMyAccount(reason: 'Leaving');
      expect(blocked, isFalse);
      expect(vm.isAuthenticated, isTrue);
      expect(vm.errorMessage, contains('رحلة إنقاذ نشطة'));

      // Delete account allowed -> signs out & deactivates token
      authRepo.deleteAccountError = null;
      final deleted = await vm.deleteMyAccount(reason: 'No longer needed');
      expect(deleted, isTrue);
      expect(vm.isAuthenticated, isFalse);
      expect(authRepo.deleteAccountCalls, 1);
      expect(authRepo.lastDeleteAccountReason, 'No longer needed');
      expect(notifRepo.deactivatedTokens, contains('fcm-abc-999'));

      vm.dispose();
      registrar.dispose();
      locale.dispose();
      await tokenProvider.dispose();
      await authRepo.dispose();
    });
  });

  group('NotificationsViewModel', () {
    test('loads notifications, reacts to realtime insert/update, and marks read', () async {
      final repo = FakeNotificationRepository();
      final vm = NotificationsViewModel(repository: repo);

      await vm.initialize('cust-1', locale: 'ar');
      expect(vm.notifications.length, 2);
      expect(vm.unreadCount, 1);
      expect(repo.activeSubscription, isNotNull);

      // Incoming Realtime notification insert
      repo.activeSubscription!.onInsert(
        TestFixtures.makeNotification(
          id: 'notif-3',
          titleAr: 'وصل السائق لموقعك',
          titleEn: 'Driver Arrived',
          isRead: false,
        ),
      );
      expect(vm.notifications.length, 3);
      expect(vm.notifications.first.id, 'notif-3');
      expect(vm.unreadCount, 2);

      // Mark single notification read
      await vm.markAsRead('notif-3');
      expect(vm.unreadCount, 1);

      // Mark all read
      await vm.markAllAsRead(userId: 'cust-1');
      expect(vm.unreadCount, 0);

      vm.dispose();
      expect(repo.activeSubscription!.disposed, isTrue);
    });
  });
}
