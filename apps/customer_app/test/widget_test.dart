import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'package:wenshy_customer/app.dart';
import 'package:wenshy_customer/data/repositories/models.dart';
import 'package:wenshy_customer/ui/core/app_dependencies.dart';
import 'package:wenshy_customer/ui/core/language_toggle_button.dart';
import 'package:wenshy_customer/ui/features/live_trip/views/live_trip_tracker_view.dart';
import 'package:wenshy_customer/ui/features/request_rescue/views/request_rescue_view.dart';

import 'fakes/fake_repositories.dart';

void main() {
  testWidgets(
    'Unauthenticated user lands on Login in Arabic RTL and can toggle to English LTR',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: false);
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        WenshyCustomerApp(dependencies: bundle.dependencies),
      );
      await tester.pumpAndSettle();

      // Default Arabic RTL
      expect(find.text('تسجيل الدخول'), findsWidgets);
      final dirWidget = Directionality.of(
        tester.element(find.byType(Scaffold)),
      );
      expect(dirWidget, TextDirection.rtl);

      // Toggle to English LTR
      await tester.tap(find.byType(LanguageToggleButton));
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr,
      );

      // Fill email/password and submit login -> redirects to Home Map & syncs profile locale
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'sara@wenshy.app',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'password123',
      );
      await tester.tap(find.widgetWithText(WenshyPrimaryButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(bundle.authRepository.signInCalls, 1);
      expect(find.text('ونشي'), findsWidgets);
    },
  );

  testWidgets(
    'Signed-in HomeMapView displays nearby winches and navigates tabs cleanly',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: true);
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        WenshyCustomerApp(dependencies: bundle.dependencies),
      );
      await tester.pumpAndSettle();

      // Map tab in Arabic
      expect(find.text('ونشي'), findsWidgets);
      expect(find.textContaining('لديك رحلة إنقاذ نشطة الآن'), findsOneWidget);

      // Switch to Saved Vehicles tab
      await tester.tap(find.text('سياراتي'));
      await tester.pumpAndSettle();
      expect(find.text('سياراتي المحفوظة'), findsOneWidget);
      expect(find.textContaining('تويوتا كورولا'), findsOneWidget);

      // Open Add Vehicle bottom sheet and save
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('إضافة سيارة جديدة'), findsWidgets);

      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'كيا');
      await tester.enterText(fields.at(1), 'سيراتو');
      await tester.enterText(fields.at(4), 'ق ط 777');
      final saveBtn = find.widgetWithText(WenshyPrimaryButton, 'حفظ');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('كيا سيراتو'), findsOneWidget);

      // Switch to Trips History tab
      await tester.tap(find.text('رحلاتي'));
      await tester.pumpAndSettle();
      expect(find.text('سجل رحلات الإنقاذ'), findsOneWidget);
      expect(find.text('WNS-1001'), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      expect(find.text('الملف الشخصي'), findsOneWidget);
    },
  );

  testWidgets(
    'RequestRescueView calculates quote and submits rescue request',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: true);
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: bundle.dependencies,
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: <Locale>[Locale('ar'), Locale('en')],
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: RequestRescueView(
              routeSelection: RouteSelection(
                pickupPoint: LatLng(30.0444, 31.2357),
                pickupAddress: 'ميدان التحرير',
                dropoffPoint: LatLng(30.0626, 31.2497),
                dropoffAddress: 'مدينة نصر',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تفاصيل طلب الإنقاذ'), findsOneWidget);
      expect(find.textContaining('470'), findsWidgets);
    },
  );

  testWidgets(
    'LiveTripTrackerView shows Wave-2 search, transitions to 6-step timeline on Realtime driver_assigned',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: true);
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        AppDependenciesScope(
          dependencies: bundle.dependencies,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: LiveTripTrackerView(
              requestId: 'req-1',
              initialRequest: TestFixtures.makeRescueRequest(),
              initialDispatch: TestFixtures.makeDispatchResult(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جاري البحث عن أقرب سائق ونش...'), findsOneWidget);
      expect(find.text('توسيع نطاق البحث (الموجة التالية)'), findsOneWidget);

      // Tap Wave-2 Retry
      await tester.tap(find.text('توسيع نطاق البحث (الموجة التالية)'));
      await tester.pumpAndSettle();
      expect(bundle.rescueRepository.lastRequestedWave, 2);
      expect(find.text('موجة البحث رقم 2'), findsOneWidget);

      // Push simulated Realtime driver assignment + location
      bundle.rescueRepository.activeSubscription!.onTripUpdate(
        TestFixtures.makeRescueRequest(
          status: 'en_route_to_pickup',
          driverId: 'drv-1',
          winchId: 'winch-1',
        ),
        <String, dynamic>{},
      );
      bundle.rescueRepository.activeSubscription!.onDriverLocation(
        TestFixtures.makeLocationPoint(lat: 30.052, lng: 31.239),
      );
      await tester.pumpAndSettle();

      expect(find.text('مراحل الرحلة'), findsOneWidget);
      expect(find.text('بيانات السائق والونش'), findsOneWidget);
      expect(find.text('كابتن كريم محمود'), findsOneWidget);

      // Direct Phone Call button renders for assigned driver and invokes PhoneDialer
      final callBtn = find.byKey(const Key('call_driver_btn'));
      await tester.ensureVisible(callBtn);
      expect(callBtn, findsOneWidget);
      await tester.tap(callBtn);
      await tester.pumpAndSettle();
      expect(bundle.phoneDialer.calledNumbers, <String>['+201112223344']);
    },
  );

  testWidgets(
    'TripDetailsView -> RateTripView and ComplaintsView -> FileComplaintView work via GoRouter',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: true);
      bundle.rescueRepository.requestsById['req-done'] =
          TestFixtures.makeRescueRequest(
        id: 'req-done',
        requestCode: 'WNS-2002',
        status: 'delivered',
        driverId: 'drv-1',
        winchId: 'winch-1',
        finalPrice: 485.0,
      );
      addTearDown(bundle.dispose);

      // Start at TripDetailsView, push to RateTripView, submit rating and pop back
      await tester.pumpWidget(
        WenshyCustomerApp(
          key: const ValueKey<String>('details-app'),
          dependencies: bundle.dependencies,
          initialLocation: '/trip/req-done/details',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('WNS-2002'), findsOneWidget);
      final rateCta = find.text('تقييم السائق');
      await tester.dragUntilVisible(
        rateCta,
        find.byType(ListView),
        const Offset(0, -250),
      );
      expect(rateCta, findsOneWidget);

      await tester.tap(rateCta);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rate_star_5')));
      await tester.tap(find.text('سرعة الوصول'));
      final submitRatingBtn = find.widgetWithText(
        WenshyPrimaryButton,
        'إرسال التقييم',
      );
      await tester.ensureVisible(submitRatingBtn);
      await tester.tap(submitRatingBtn);
      await tester.pumpAndSettle();
      expect(bundle.feedbackRepository.storedRating, isNotNull);
      expect(bundle.feedbackRepository.storedRating!.score, 5);
      expect(find.textContaining('تم تقييم هذه الرحلة مسبقاً'), findsOneWidget);

      // Navigate via router from ComplaintsView -> FileComplaintView and submit
      await tester.pumpWidget(
        WenshyCustomerApp(
          key: const ValueKey<String>('complaints-app'),
          dependencies: bundle.dependencies,
          initialLocation: '/complaints',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CMP-201'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'رسوم إضافية غير متفق عليها');
      await tester.enterText(
        inputs.at(1),
        'السائق طلب دفع فرق غير مذكور في التسعيرة.',
      );
      final submitComplaintBtn = find.widgetWithText(
        WenshyPrimaryButton,
        'إرسال الشكوى',
      );
      await tester.ensureVisible(submitComplaintBtn);
      await tester.tap(submitComplaintBtn);
      await tester.pumpAndSettle();
      expect(bundle.feedbackRepository.complaints.length, 2);
      expect(find.text('رسوم إضافية غير متفق عليها'), findsOneWidget);
    },
  );

  testWidgets(
    'LoginView supports Forgot Password dialog and Phone OTP verification flow',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: false);
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        WenshyCustomerApp(dependencies: bundle.dependencies),
      );
      await tester.pumpAndSettle();

      // Open Forgot Password dialog and submit
      await tester.tap(find.byKey(const Key('forgot_password_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('forgot_password_email_field')),
        'reset@wenshy.app',
      );
      await tester.tap(find.byKey(const Key('forgot_password_submit_btn')));
      await tester.pumpAndSettle();

      expect(bundle.authRepository.lastPasswordResetEmail, 'reset@wenshy.app');
      expect(find.textContaining('إعادة تعيين كلمة المرور'), findsOneWidget);

      // Switch to Phone OTP login mode
      await tester.tap(find.text('رقم الهاتف (OTP)'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('otp_phone_field')),
        '+201009998877',
      );
      await tester.tap(find.byKey(const Key('send_otp_btn')));
      await tester.pumpAndSettle();

      expect(bundle.authRepository.lastOtpPhone, '+201009998877');
      expect(find.byKey(const Key('otp_code_field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('otp_code_field')), '654321');
      await tester.tap(find.byKey(const Key('verify_otp_btn')));
      await tester.pumpAndSettle();

      expect(bundle.authRepository.lastVerifiedOtpToken, '654321');
      expect(bundle.authViewModel.isAuthenticated, isTrue);
      expect(find.text('ونشي'), findsWidgets);
    },
  );

  testWidgets(
    'ProfileView Delete Account dialog handles active-trip error and successful deletion',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: true);
      bundle.authRepository.deleteAccountError =
          Exception('P0001: active trip exists');
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        WenshyCustomerApp(
          dependencies: bundle.dependencies,
          initialLocation: '/profile',
        ),
      );
      await tester.pumpAndSettle();

      final deleteBtn = find.byKey(const Key('delete_account_btn'));
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('delete_account_reason_field')),
        'تجربة',
      );
      await tester.tap(find.byKey(const Key('confirm_delete_account_btn')));
      await tester.pumpAndSettle();

      // Blocked by active trip -> still signed in with friendly error message
      expect(bundle.authViewModel.isAuthenticated, isTrue);
      expect(find.textContaining('رحلة إنقاذ نشطة'), findsWidgets);

      // Let the error SnackBar dismiss so Delete Account button is unobstructed
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Now allow deletion
      bundle.authRepository.deleteAccountError = null;
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_account_btn')));
      await tester.pumpAndSettle();

      expect(bundle.authRepository.deleteAccountCalls, 1);
      expect(bundle.authViewModel.isAuthenticated, isFalse);
      expect(find.text('تسجيل الدخول'), findsWidgets);
    },
  );

  testWidgets(
    'HomeMapView place search autocomplete sets dropoff route and opens Notifications inbox',
    (tester) async {
      final bundle = TestDependencyBundle(initiallySignedIn: true);
      addTearDown(bundle.dispose);

      await tester.pumpWidget(
        WenshyCustomerApp(dependencies: bundle.dependencies),
      );
      await tester.pumpAndSettle();

      // Open Dropoff place search sheet
      await tester.tap(find.byKey(const Key('search_dropoff_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('place_search_input')),
        'مدينة نصر',
      );
      // Wait for 350ms debounce timer to fire
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('عباس العقاد، مدينة نصر'), findsOneWidget);
      await tester.tap(find.byKey(const Key('place_suggestion_1')));
      await tester.pumpAndSettle();

      // Road route distance badge appears on HomeMapView
      expect(find.byKey(const Key('route_distance_badge')), findsOneWidget);
      expect(find.textContaining('12.4'), findsOneWidget);

      // Tap Notifications bell button -> opens NotificationsView
      await tester.tap(find.byKey(const Key('notifications_bell_btn')));
      await tester.pumpAndSettle();

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('تم تعيين سائق للرحلة'), findsOneWidget);
      expect(bundle.notificationsViewModel.unreadCount, 1);

      // Mark all read clears unread count
      await tester.tap(find.byKey(const Key('mark_all_read_btn')));
      await tester.pumpAndSettle();
      expect(bundle.notificationsViewModel.unreadCount, 0);
    },
  );
}
