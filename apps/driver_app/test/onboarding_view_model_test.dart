import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/data/services/media_picker_service.dart';
import 'package:wenshy_driver/ui/features/onboarding/view_models/onboarding_view_model.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  group('OnboardingViewModel', () {
    test('loads winch types, existing winches, and KYC documents', () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(
          approvalStatus: DriverApprovalStatus.pending,
        ),
      );
      final onboardingRepo = FakeDriverOnboardingRepository()
        ..documents = <DriverDocument>[
          DriverDocument(
            id: 'doc-1',
            driverId: 'driver-1',
            documentType: DocumentType.nationalIdFront,
            storagePath: 'driver-1/national_id_front/id.jpg',
            reviewStatus: DocumentReviewStatus.approved,
            createdAt: TestFixtures.baseTime,
            updatedAt: TestFixtures.baseTime,
          ),
        ];
      final deps = createTestDependencies(
        authRepository: authRepo,
        onboardingRepository: onboardingRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = OnboardingViewModel(
        onboardingRepository: onboardingRepo,
        sessionController: deps.sessionController,
        mediaPicker: deps.mediaPicker,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      await vm.loadOnboardingData();

      expect(vm.winchTypes, hasLength(1));
      expect(vm.uploadedDocumentsCount, 1);
      expect(vm.rejectedDocumentsCount, 0);
      expect(vm.hasRegisteredWinch, isFalse);
    });

    test('stages winch photos and registers driver tow truck', () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(
          approvalStatus: DriverApprovalStatus.pending,
        ),
      );
      final onboardingRepo = FakeDriverOnboardingRepository();
      final mediaPicker = FakeDriverMediaPicker()
        ..nextFile = PickedMediaFile(
          bytes: Uint8List.fromList(<int>[10, 20, 30]),
          fileName: 'winch_front.jpg',
          contentType: 'image/jpeg',
        );
      final deps = createTestDependencies(
        authRepository: authRepo,
        onboardingRepository: onboardingRepo,
        mediaPicker: mediaPicker,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = OnboardingViewModel(
        onboardingRepository: onboardingRepo,
        sessionController: deps.sessionController,
        mediaPicker: mediaPicker,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      await vm.pickWinchPhoto(source: ImageSource.camera);
      expect(vm.stagedWinchPhotos, hasLength(1));

      final created = await vm.registerWinch(
        winchTypeId: 'wt-flatbed',
        plateNumber: 'س ص ع 9876',
        brand: 'Isuzu',
        model: 'NPR',
        year: 2023,
        maxCapacityTons: 5.5,
      );

      expect(created, isTrue);
      expect(vm.hasRegisteredWinch, isTrue);
      expect(vm.winches.first.plateNumber, 'س ص ع 9876');
      expect(vm.winches.first.photoPaths, <String>['driver-1/winch_front.jpg']);
      expect(vm.stagedWinchPhotos, isEmpty);
    });

    test('re-uploading rejected KYC document upserts and resets to pending',
        () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(
          approvalStatus: DriverApprovalStatus.rejected,
          rejectionReason: 'صورة الرخصة غير واضحة',
        ),
      );
      final onboardingRepo = FakeDriverOnboardingRepository()
        ..documents = <DriverDocument>[
          DriverDocument(
            id: 'doc-driver_license_front',
            driverId: 'driver-1',
            documentType: DocumentType.driverLicenseFront,
            storagePath: 'driver-1/driver_license_front/old.jpg',
            reviewStatus: DocumentReviewStatus.rejected,
            rejectionReason: 'غير واضحة',
            createdAt: TestFixtures.baseTime,
            updatedAt: TestFixtures.baseTime,
          ),
        ];
      final deps = createTestDependencies(
        authRepository: authRepo,
        onboardingRepository: onboardingRepo,
      );
      addTearDown(deps.dispose);
      await deps.sessionController.initialize();

      final vm = OnboardingViewModel(
        onboardingRepository: onboardingRepo,
        sessionController: deps.sessionController,
        mediaPicker: deps.mediaPicker,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      await vm.loadOnboardingData();
      expect(vm.rejectedDocumentsCount, 1);

      final ok = await vm.pickAndUploadDocument(
        documentType: DocumentType.driverLicenseFront,
        source: ImageSource.gallery,
      );

      expect(ok, isTrue);
      expect(onboardingRepo.upsertCalls, 1);
      expect(vm.rejectedDocumentsCount, 0);
      final updated = vm.documentForType(DocumentType.driverLicenseFront)!;
      expect(updated.reviewStatus, DocumentReviewStatus.pending);
      expect(updated.rejectionReason, isNull);
    });
  });
}
