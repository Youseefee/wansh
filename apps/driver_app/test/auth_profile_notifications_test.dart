import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/app.dart';
import 'package:wenshy_driver/data/services/push_token_service.dart';
import 'package:wenshy_driver/ui/core/app_router.dart';
import 'package:wenshy_driver/ui/core/widgets/driver_widgets.dart';
import 'package:wenshy_driver/ui/features/auth/views/login_view.dart';
import 'package:wenshy_driver/ui/features/notifications/views/driver_notifications_view.dart';
import 'package:wenshy_driver/ui/features/profile/views/driver_profile_view.dart';

import 'fakes/fake_driver_repositories.dart';

void main() {
  group('Auth Enhancements: Forgot Password & Phone OTP', () {
    testWidgets('LoginView sends password reset email via Forgot Password dialog',
        (tester) async {
      final authRepo = FakeDriverAuthRepository();
      final deps = createTestDependencies(authRepository: authRepo);
      final vm = deps.createAuthViewModel();
      addTearDown(() {
        vm.dispose();
        deps.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LoginView(
              viewModel: vm,
              localeController: deps.localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('forgot_password_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('forgot_password_email_field')),
        'driver@wenshy.test',
      );
      await tester.tap(find.byKey(const Key('send_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(authRepo.lastPasswordResetEmail, 'driver@wenshy.test');
      expect(vm.infoMessage, isNotNull);
    });

    testWidgets('LoginView supports Phone OTP send & verify flow',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: null,
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      final vm = deps.createAuthViewModel();
      addTearDown(() {
        vm.dispose();
        deps.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: LoginView(
              viewModel: vm,
              localeController: deps.localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Phone OTP tab
      await tester.tap(find.text('رمز الهاتف (OTP)'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('otp_phone_field')),
        '+201001234567',
      );
      await tester.tap(find.byKey(const Key('send_otp_btn')));
      await tester.pumpAndSettle();

      expect(authRepo.lastOtpPhone, '+201001234567');
      expect(vm.otpSent, isTrue);

      await tester.enterText(
        find.byKey(const Key('otp_code_field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('verify_otp_btn')));
      await tester.pumpAndSettle();

      expect(authRepo.lastVerifiedOtpPhone, '+201001234567');
      expect(authRepo.lastVerifiedOtpToken, '123456');
      expect(deps.sessionController.isAuthenticated, isTrue);
    });
  });

  group('Editable Driver Profile & Delete Account', () {
    testWidgets('DriverProfileView updates full name & phone and refreshes session',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(fullName: 'محمود أحمد'),
        driverProfile: TestFixtures.driverProfile(),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      await deps.sessionController.initialize();
      addTearDown(deps.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DriverProfileView(
              sessionController: deps.sessionController,
              localeController: deps.localeController,
              notificationsController: deps.notificationsController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محمود أحمد'), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit_profile_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('edit_profile_name_field')),
        'محمود حسن السعيد',
      );
      await tester.enterText(
        find.byKey(const Key('edit_profile_phone_field')),
        '+201099112233',
      );
      await tester.tap(find.byKey(const Key('save_profile_btn')));
      await tester.pumpAndSettle();

      expect(deps.sessionController.userProfile?.fullName, 'محمود حسن السعيد');
      expect(deps.sessionController.userProfile?.phone, '+201099112233');
      expect(find.text('محمود حسن السعيد'), findsOneWidget);
      expect(find.text('+201099112233'), findsOneWidget);
    });

    testWidgets(
        'DriverProfileView handles active-trip protection error gracefully on Delete Account',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      )..deleteAccountError = const PostgrestException(
          message: 'Cannot delete account with an active in-progress trip',
          code: 'P0001',
        );
      final notifRepo = FakeDriverNotificationRepository();
      final deps = createTestDependencies(
        authRepository: authRepo,
        notificationRepository: notifRepo,
        pushTokenProvider: FakeDriverPushTokenProvider(
          token: 'active-trip-fcm-token',
        ),
      );
      await deps.sessionController.initialize();
      await tester.pump();
      addTearDown(deps.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DriverProfileView(
              sessionController: deps.sessionController,
              localeController: deps.localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byKey(const Key('delete_account_btn'));
      await tester.dragUntilVisible(
        deleteBtn,
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_delete_account_btn')));
      await tester.pumpAndSettle();

      expect(deps.sessionController.isAuthenticated, isTrue);
      expect(notifRepo.deactivatedTokens, isEmpty);
      expect(
        deps.pushTokenRegistrar.lastRegisteredToken,
        'active-trip-fcm-token',
      );
      expect(
        find.textContaining('رحلة إنقاذ جارية'),
        findsOneWidget,
      );
    });

    testWidgets('DriverProfileView deletes account and clears session on success',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final deps = createTestDependencies(authRepository: authRepo);
      await deps.sessionController.initialize();
      addTearDown(deps.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DriverProfileView(
              sessionController: deps.sessionController,
              localeController: deps.localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byKey(const Key('delete_account_btn'));
      await tester.dragUntilVisible(
        deleteBtn,
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('delete_account_reason_field')),
        'توقف مؤقت عن العمل',
      );
      await tester.tap(find.byKey(const Key('confirm_delete_account_btn')));
      await tester.pumpAndSettle();

      expect(authRepo.deleteAccountCalled, isTrue);
      expect(authRepo.lastDeleteReason, 'توقف مؤقت عن العمل');
      expect(deps.sessionController.isAuthenticated, isFalse);
    });
  });

  group('Notifications Inbox & Push Token Hook', () {
    testWidgets(
        'loads notifications, updates unread badge in real time, and supports markAsRead / markAllAsRead',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final notifRepo = FakeDriverNotificationRepository(
        initialNotifications: <AppNotification>[
          AppNotification(
            id: 'notif-1',
            userId: 'driver-1',
            titleAr: 'طلب إنقاذ جديد',
            titleEn: 'New Rescue Offer',
            bodyAr: 'يوجد طلب قريب منك في مدينة نصر',
            bodyEn: 'A nearby request is waiting in Nasr City',
            type: 'dispatch_offer_new',
            isRead: false,
            createdAt: TestFixtures.baseTime,
          ),
          AppNotification(
            id: 'notif-2',
            userId: 'driver-1',
            titleAr: 'تم اعتماد حسابك',
            titleEn: 'Account Approved',
            bodyAr: 'أهلاً بك في أسطول ونشي',
            bodyEn: 'Welcome to the Wenshy fleet',
            type: 'driver_approved',
            isRead: true,
            createdAt: TestFixtures.baseTime.subtract(const Duration(hours: 2)),
          ),
        ],
      );
      final deps = createTestDependencies(
        authRepository: authRepo,
        notificationRepository: notifRepo,
      );
      await deps.sessionController.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DriverNotificationsView(
              controller: deps.notificationsController,
              localeController: deps.localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(deps.dispose);

      expect(deps.notificationsController.unreadCount, 1);
      expect(find.text('طلب إنقاذ جديد'), findsOneWidget);
      expect(find.text('تم اعتماد حسابك'), findsOneWidget);

      // Emit a Realtime notification
      notifRepo.realtimeController.add(
        AppNotification(
          id: 'notif-3',
          userId: 'driver-1',
          titleAr: 'تم إلغاء الرحلة',
          titleEn: 'Trip Cancelled',
          bodyAr: 'قام العميل بإلغاء الطلب',
          bodyEn: 'Customer cancelled the trip',
          type: 'trip_cancelled',
          isRead: false,
          createdAt: TestFixtures.baseTime.add(const Duration(minutes: 5)),
        ),
      );
      await tester.pumpAndSettle();

      expect(deps.notificationsController.unreadCount, 2);
      expect(find.text('تم إلغاء الرحلة'), findsOneWidget);

      // Mark single notification as read
      await deps.notificationsController.markAsRead('notif-3');
      await tester.pumpAndSettle();
      expect(deps.notificationsController.unreadCount, 1);
      expect(notifRepo.markedReadIds, contains('notif-3'));

      // Mark all as read from AppBar action
      await tester.tap(find.text('تحديد الكل كمقروء'));
      await tester.pumpAndSettle();
      expect(deps.notificationsController.unreadCount, 0);
      expect(notifRepo.markedAllReadUserIds, <String>['driver-1']);
    });

    testWidgets('NotificationsBellButton displays badge and opens /notifications route',
        (tester) async {
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final notifRepo = FakeDriverNotificationRepository(
        initialNotifications: <AppNotification>[
          AppNotification(
            id: 'notif-1',
            userId: 'driver-1',
            titleAr: 'عرض إنقاذ عاجل',
            titleEn: 'Urgent Rescue Offer',
            bodyAr: 'على بعد 2 كم منك',
            bodyEn: '2 km away from you',
            type: 'dispatch_offer_new',
            isRead: false,
            createdAt: TestFixtures.baseTime,
          ),
        ],
      );
      final deps = createTestDependencies(
        authRepository: authRepo,
        notificationRepository: notifRepo,
      );
      await deps.sessionController.initialize();
      final router = createDriverRouter(deps, initialLocation: '/home');
      addTearDown(() {
        router.dispose();
        deps.dispose();
      });

      await tester.pumpWidget(
        WenshyDriverApp(dependencies: deps, router: router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsBellButton), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byType(NotificationsBellButton));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/notifications');
      expect(find.text('عرض إنقاذ عاجل'), findsOneWidget);

      // Clean up periodic timers on home if any
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    test('push token registrar registers token on session init, deactivates on signOut, and never crashes when unavailable',
        () async {
      final notifRepo = FakeDriverNotificationRepository();
      final tokenProvider = FakeDriverPushTokenProvider(
        token: 'fcm-driver-token-123',
      );
      final authRepo = FakeDriverAuthRepository(
        userId: 'driver-1',
        userProfile: TestFixtures.driverUserProfile(),
        driverProfile: TestFixtures.driverProfile(),
      );
      final deps = createTestDependencies(
        authRepository: authRepo,
        notificationRepository: notifRepo,
        pushTokenProvider: tokenProvider,
      );
      addTearDown(deps.dispose);

      await deps.sessionController.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(notifRepo.registeredTokens, hasLength(1));
      expect(notifRepo.registeredTokens.first['userId'], 'driver-1');
      expect(notifRepo.registeredTokens.first['token'], 'fcm-driver-token-123');
      expect(notifRepo.registeredTokens.first['platform'], 'android');

      await deps.sessionController.signOut();
      expect(notifRepo.deactivatedTokens, <String>['fcm-driver-token-123']);

      // Verify throwing token provider does NOT crash registration
      final failingRegistrar = DriverPushTokenRegistrar(
        notificationRepository: notifRepo,
        tokenProvider: FakeDriverPushTokenProvider(
          error: StateError('Firebase not initialized'),
        ),
        platformOverride: TargetPlatform.android,
        isWebOverride: false,
      );
      final ok = await failingRegistrar.registerForUser('driver-1');
      expect(ok, isFalse);
    });
  });
}
