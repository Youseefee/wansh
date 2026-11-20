import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/data/repositories/driver_dispatch_repository.dart';
import 'package:wenshy_driver/ui/features/home/view_models/driver_home_view_model.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  group('DriverHomeViewModel', () {
    test('toggleOnline syncs PostGIS location RPC and manages fleet:online Presence',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(isOnline: false),
      );
      final dispatchRepo = FakeDriverDispatchRepository();
      final deps = createTestDependencies(
        authRepository: authRepo,
        dispatchRepository: dispatchRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = DriverHomeViewModel(
        dispatchRepository: dispatchRepo,
        tripRepository: deps.tripRepository,
        locationSource: deps.locationSource,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      await vm.initialize();
      expect(vm.isOnline, isFalse);

      await vm.toggleOnline(true);
      expect(vm.isOnline, isTrue);
      expect(dispatchRepo.joinedPresence, isTrue);
      expect(dispatchRepo.locationSyncCalls.last['p_is_online'], isTrue);
      expect(deps.sessionController.driverProfile?.isOnline, isTrue);

      await vm.toggleOnline(false);
      expect(vm.isOnline, isFalse);
      expect(dispatchRepo.leftPresence, isTrue);
      expect(dispatchRepo.locationSyncCalls.last['p_is_online'], isFalse);
    });

    test('receives realtime dispatch offer, counts down, and handles UPDATE closure',
        () async {
      var now = DateTime.utc(2026, 11, 12, 18, 0, 0);
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(isOnline: true),
      );
      final dispatchRepo = FakeDriverDispatchRepository();
      final deps = createTestDependencies(
        authRepository: authRepo,
        dispatchRepository: dispatchRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = DriverHomeViewModel(
        dispatchRepository: dispatchRepo,
        tripRepository: deps.tripRepository,
        locationSource: deps.locationSource,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
        clock: () => now,
      );
      addTearDown(vm.dispose);

      await vm.initialize();

      final offer = TestFixtures.dispatchOffer(
        id: 'offer-rt',
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
      );
      dispatchRepo.offersController.add(
        DispatchOfferEvent(
          eventType: RealtimeTopics.insertEvent,
          offer: offer,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.activeOffer?.id, 'offer-rt');
      expect(vm.offerRemaining.inSeconds, 30);

      // Simulate offer taken by another driver / expired on backend.
      dispatchRepo.offersController.add(
        DispatchOfferEvent(
          eventType: RealtimeTopics.updateEvent,
          offer: offer.copyWith(status: OfferStatus.expired),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.activeOffer, isNull);
      expect(vm.statusMessage, isNotNull);
    });

    test('acceptCurrentOffer claims trip and sets activeTripId; rejectCurrentOffer clears',
        () async {
      final now = DateTime.utc(2026, 11, 12, 18, 0, 0);
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(isOnline: true),
      );
      final dispatchRepo = FakeDriverDispatchRepository();
      final deps = createTestDependencies(
        authRepository: authRepo,
        dispatchRepository: dispatchRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = DriverHomeViewModel(
        dispatchRepository: dispatchRepo,
        tripRepository: deps.tripRepository,
        locationSource: deps.locationSource,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
        clock: () => now,
      );
      addTearDown(vm.dispose);

      await vm.initialize();

      final offer1 = TestFixtures.dispatchOffer(
        id: 'offer-reject',
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 40)),
      );
      dispatchRepo.offersController.add(
        DispatchOfferEvent(
          eventType: RealtimeTopics.insertEvent,
          offer: offer1,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.activeOffer?.id, 'offer-reject');

      await vm.rejectCurrentOffer(reason: 'Busy');
      expect(dispatchRepo.lastRejectedOfferId, 'offer-reject');
      expect(vm.activeOffer, isNull);

      final offer2 = TestFixtures.dispatchOffer(
        id: 'offer-accept',
        requestId: 'req-claimed',
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 40)),
      );
      dispatchRepo.nextAcceptResult = const AcceptOfferResult(
        accepted: true,
        requestId: 'req-claimed',
        requestCode: 'WN-200002',
        status: TripStatus.driverAssigned,
      );
      dispatchRepo.offersController.add(
        DispatchOfferEvent(
          eventType: RealtimeTopics.insertEvent,
          offer: offer2,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final claimedId = await vm.acceptCurrentOffer();
      expect(claimedId, 'req-claimed');
      expect(dispatchRepo.lastAcceptedOfferId, 'offer-accept');
      expect(deps.sessionController.activeTripId, 'req-claimed');
      expect(vm.activeOffer, isNull);
    });
  });
}
