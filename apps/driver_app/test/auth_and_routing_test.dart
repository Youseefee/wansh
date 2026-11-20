import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/ui/core/app_router.dart';
import 'package:wenshy_driver/ui/core/driver_session_controller.dart';
import 'package:wenshy_driver/ui/features/auth/view_models/auth_view_model.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  group('AuthViewModel & DriverSessionController', () {
    test('signIn authenticates valid driver and loads session', () async {
      final authRepo = FakeDriverAuthRepository(
        userId: null,
        userProfile: TestFixtures.driverUserProfile(locale: 'en'),
        driverProfile: TestFixtures.driverProfile(
          approvalStatus: DriverApprovalStatus.approved,
        ),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      addTearDown(deps.dispose);

      final vm = AuthViewModel(
        authRepository: authRepo,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      final ok = await vm.signIn(
        email: 'driver@wenshy.test',
        password: 'password123',
      );

      expect(ok, isTrue);
      expect(vm.errorMessage, isNull);
      expect(deps.sessionController.isAuthenticated, isTrue);
      expect(deps.sessionController.isApproved, isTrue);
      expect(deps.localeController.localeCode, 'en');
    });

    test('signIn rejects non-driver account with role error', () async {
      final authRepo = FakeDriverAuthRepository(
        userProfile: TestFixtures.driverUserProfile(role: AppRole.customer),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      addTearDown(deps.dispose);

      final vm = AuthViewModel(
        authRepository: authRepo,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      final ok = await vm.signIn(
        email: 'customer@wenshy.test',
        password: 'password123',
      );

      expect(ok, isFalse);
      expect(vm.errorMessage, isNotNull);
      expect(deps.sessionController.isAuthenticated, isFalse);
    });

    test('registerDriver passes driver role, national ID, and license number',
        () async {
      final authRepo = FakeDriverAuthRepository();
      final deps = createTestDependencies(authRepository: authRepo);
      addTearDown(deps.dispose);

      final vm = AuthViewModel(
        authRepository: authRepo,
        sessionController: deps.sessionController,
        localeController: deps.localeController,
      );
      addTearDown(vm.dispose);

      final ok = await vm.registerDriver(
        email: 'new.driver@wenshy.test',
        password: 'StrongPassword1!',
        fullName: 'أحمد حسن',
        phone: '+201099887766',
        nationalIdNumber: '29505051234567',
        licenseNumber: 'DL-554433',
      );

      expect(ok, isTrue);
      expect(authRepo.lastSignUpArgs, <String, dynamic>{
        'role': 'driver',
        'email': 'new.driver@wenshy.test',
        'full_name': 'أحمد حسن',
        'phone': '+201099887766',
        'national_id_number': '29505051234567',
        'license_number': 'DL-554433',
        'locale': 'ar',
      });
      expect(deps.sessionController.isAuthenticated, isTrue);
      expect(deps.sessionController.isApproved, isFalse);
      expect(
        deps.sessionController.driverProfile?.approvalStatus,
        DriverApprovalStatus.pending,
      );
    });

    test('non-driver existing session signs out on refreshSession', () async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'cust-1',
        userProfile: TestFixtures.driverUserProfile(
          id: 'cust-1',
          role: AppRole.customer,
        ),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      addTearDown(deps.dispose);

      await deps.sessionController.initialize();

      expect(deps.sessionController.status, DriverSessionStatus.unauthenticated);
      expect(deps.sessionController.errorMessage, 'invalid_role');
      expect(authRepo.currentUserId, isNull);
    });
  });

  group('GoRouter Auth & Approval Gate Redirects', () {
    testWidgets('redirects initializing -> /splash, unauthenticated -> /login',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(userId: null);
      final deps = createTestDependencies(authRepository: authRepo);
      final router = createDriverRouter(deps, initialLocation: '/home');
      addTearDown(() {
        router.dispose();
        deps.dispose();
      });

      expect(router.routeInformationProvider.value.uri.path, '/home');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      expect(router.state.matchedLocation, '/splash');

      await deps.sessionController.initialize();
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/login');
    });

    testWidgets('gates unapproved driver to /approval-gate but allows KYC/winch',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(
          approvalStatus: DriverApprovalStatus.rejected,
          rejectionReason: 'صورة الرخصة غير واضحة',
        ),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      await deps.sessionController.initialize();
      final router = createDriverRouter(deps, initialLocation: '/home');
      addTearDown(() {
        router.dispose();
        deps.dispose();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/approval-gate');

      router.go('/onboarding/kyc');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/onboarding/kyc');

      router.go('/onboarding/winch');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/onboarding/winch');
    });

    testWidgets('routes approved driver to /home', (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(
          approvalStatus: DriverApprovalStatus.approved,
        ),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      await deps.sessionController.initialize();
      final router = createDriverRouter(deps, initialLocation: '/approval-gate');
      addTearDown(() {
        router.dispose();
        deps.dispose();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/home');
    });
  });
}
