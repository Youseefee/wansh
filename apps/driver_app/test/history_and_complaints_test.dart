import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/data/services/media_picker_service.dart';
import 'package:wenshy_driver/ui/features/complaints/view_models/complaints_view_model.dart';
import 'package:wenshy_driver/ui/features/history/view_models/trips_history_view_model.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  group('TripsHistoryViewModel & ComplaintsViewModel', () {
    test('exposes driver total_trips, total_earnings, avg_rating, trips, and ratings',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(
          totalTrips: 27,
          totalEarnings: 14250.0,
          avgRating: 4.88,
          totalRatings: 22,
        ),
      );
      final historyRepo = FakeDriverHistoryRepository()
        ..trips = <RescueRequest>[
          TestFixtures.rescueRequest(
            id: 'req-past-1',
            status: TripStatus.delivered,
          ).copyWith(finalPrice: 620),
        ]
        ..ratings = <TripRating>[
          TripRating(
            id: 'rate-1',
            requestId: 'req-past-1',
            customerId: 'cust-1',
            driverId: 'driver-1',
            score: 5,
            comment: 'خدمة ممتازة وسريعة',
            createdAt: TestFixtures.baseTime,
          ),
        ];

      final deps = createTestDependencies(
        authRepository: authRepo,
        historyRepository: historyRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = TripsHistoryViewModel(
        historyRepository: historyRepo,
        sessionController: deps.sessionController,
      );
      addTearDown(vm.dispose);

      await vm.loadHistory();

      expect(vm.totalTrips, 27);
      expect(vm.totalEarnings, 14250.0);
      expect(vm.avgRating, 4.88);
      expect(vm.totalRatings, 22);
      expect(vm.trips, hasLength(1));
      expect(vm.ratings, hasLength(1));
    });

    test('submits complaint with evidence files and updates complaint feed',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final pastTrip = TestFixtures.rescueRequest(
        id: 'req-cmp',
        status: TripStatus.delivered,
      );
      final historyRepo = FakeDriverHistoryRepository()
        ..trips = <RescueRequest>[pastTrip];
      final deps = createTestDependencies(
        authRepository: authRepo,
        historyRepository: historyRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = ComplaintsViewModel(
        historyRepository: historyRepo,
        sessionController: deps.sessionController,
        mediaPicker: deps.mediaPicker,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      await vm.loadComplaints();
      expect(vm.driverTrips, hasLength(1));

      vm.stageEvidenceFile(
        PickedMediaFile(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'damage_photo.jpg',
          contentType: 'image/jpeg',
        ),
      );
      expect(vm.stagedEvidence, hasLength(1));

      final submitted = await vm.submitComplaint(
        category: ComplaintCategory.pricing,
        subject: 'مشكلة في تسوية الأجرة',
        description: 'المبلغ المحصل يختلف عن المسجل في النظام.',
        relatedTrip: pastTrip,
      );

      expect(submitted, isTrue);
      expect(vm.complaints, hasLength(1));
      expect(vm.complaints.first.requestId, 'req-cmp');
      expect(vm.complaints.first.reportedUserId, pastTrip.customerId);
      expect(
        vm.complaints.first.evidencePaths,
        <String>['driver-1/damage_photo.jpg'],
      );
      expect(vm.stagedEvidence, isEmpty);
      expect(vm.successMessage, isNotNull);
    });
  });
}
