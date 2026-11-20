import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/app.dart';
import 'package:wenshy_driver/ui/core/app_router.dart';
import 'package:wenshy_driver/ui/features/home/views/incoming_offer_sheet.dart';
import 'package:wenshy_driver/ui/features/onboarding/views/approval_gate_view.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  testWidgets('WenshyDriverApp defaults to Arabic RTL and toggles to English LTR',
      (tester) async {
    final authRepo = FakeDriverAuthRepository(userId: null);
    final deps = createTestDependencies(authRepository: authRepo);
    await deps.sessionController.initialize();
    final router = createDriverRouter(deps, initialLocation: '/login');
    addTearDown(() {
      router.dispose();
      deps.dispose();
    });

    await tester.pumpWidget(
      WenshyDriverApp(dependencies: deps, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('تسجيل دخول السائق'), findsOneWidget);
    final scaffoldElement = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(scaffoldElement), TextDirection.rtl);

    await tester.tap(
      find.ancestor(
        of: find.text('EN'),
        matching: find.byType(ActionChip),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Driver Sign In'), findsOneWidget);
    final ltrElement = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(ltrElement), TextDirection.ltr);
  });

  testWidgets('ApprovalGateView shows rejection reason and onboarding steps',
      (tester) async {
    final authRepo = FakeDriverAuthRepository(
      userId: 'driver-1',
      userProfile: TestFixtures.driverUserProfile(),
      driverProfile: TestFixtures.driverProfile(
        approvalStatus: DriverApprovalStatus.rejected,
        rejectionReason: 'صورة الرخصة غير واضحة، يرجى إعادة التصوير',
      ),
    );
    final deps = createTestDependencies(authRepository: authRepo);
    await deps.sessionController.initialize();
    final vm = deps.createOnboardingViewModel();
    addTearDown(() {
      vm.dispose();
      deps.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: WenshyTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ApprovalGateView(
            viewModel: vm,
            sessionController: deps.sessionController,
            localeController: deps.localeController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حالة اعتماد الحساب'), findsOneWidget);
    expect(find.text('مرفوض'), findsOneWidget);
    expect(
      find.text('صورة الرخصة غير واضحة، يرجى إعادة التصوير'),
      findsOneWidget,
    );
    expect(find.text('بيانات الونش وصوره'), findsOneWidget);
    expect(find.text('المستندات الرسمية (KYC)'), findsOneWidget);
  });

  testWidgets('DriverHomeView toggles Online switch and displays active offer',
      (tester) async {
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
    await deps.sessionController.initialize();
    final router = createDriverRouter(deps, initialLocation: '/home');
    addTearDown(() async {
      router.dispose();
      deps.dispose();
    });

    await tester.pumpWidget(
      WenshyDriverApp(dependencies: deps, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('غير متصل حالياً'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('متصل وجاهز للطلبات'), findsOneWidget);
    expect(dispatchRepo.joinedPresence, isTrue);

    // Unmount tree first so _OwnedVmPage cancels periodic heartbeat timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('IncomingOfferCard renders countdown, details, and action buttons',
      (tester) async {
    var accepted = false;
    var rejected = false;
    final offer = TestFixtures.dispatchOffer();

    await tester.pumpWidget(
      MaterialApp(
        theme: WenshyTheme.light(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: IncomingOfferCard(
                offer: offer,
                remaining: const Duration(seconds: 32),
                locale: 'ar',
                isBusy: false,
                onAccept: () => accepted = true,
                onReject: () => rejected = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('طلب إنقاذ جديد!'), findsOneWidget);
    expect(find.text('WN-100001'), findsOneWidget);
    expect(find.text('32s'), findsOneWidget);
    expect(find.text('كوبري 6 أكتوبر، القاهرة'), findsOneWidget);
    expect(find.text('مدينة نصر، القاهرة'), findsOneWidget);

    await tester.tap(find.text('قبول الطلب'));
    await tester.pump();
    expect(accepted, isTrue);

    await tester.tap(find.text('رفض'));
    await tester.pump();
    expect(rejected, isTrue);
  });
}
