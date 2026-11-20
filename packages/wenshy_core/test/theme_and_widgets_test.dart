import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';

void main() {
  group('WenshyTheme and shared widgets', () {
    test('light and dark themes expose Wenshy brand palette', () {
      final light = WenshyTheme.light();
      expect(light.useMaterial3, isTrue);
      expect(light.colorScheme.primary, WenshyColors.amber);
      expect(light.colorScheme.onPrimary, WenshyColors.deepSlate);
      expect(light.colorScheme.error, WenshyColors.red);

      final dark = WenshyTheme.dark();
      expect(dark.useMaterial3, isTrue);
      expect(dark.colorScheme.primary, WenshyColors.amber);
      expect(dark.scaffoldBackgroundColor, WenshyColors.deepSlate);

      expect(light.textTheme.titleLarge?.fontFamily, WenshyTheme.defaultFontFamily);
      expect(
        light.textTheme.bodyMedium?.fontFamilyFallback,
        contains('Cairo'),
      );
      expect(light.textTheme.bodyMedium?.height, greaterThanOrEqualTo(1.4));
      expect(dark.textTheme.headlineMedium?.fontFamily, WenshyTheme.defaultFontFamily);

      final custom = WenshyTheme.light(fontFamily: 'Tajawal');
      expect(custom.textTheme.bodyLarge?.fontFamily, 'Tajawal');
      expect(custom.appBarTheme.titleTextStyle?.fontFamily, 'Tajawal');
    });

    testWidgets('WenshyStatusBadge renders localized trip and approval labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                WenshyStatusBadge.trip(TripStatus.delivered, locale: 'ar'),
                WenshyStatusBadge.driverApproval(
                  DriverApprovalStatus.approved,
                  locale: 'en',
                ),
                WenshyStatusBadge.documentReview(
                  DocumentReviewStatus.rejected,
                  locale: 'en',
                ),
                WenshyStatusBadge.complaint(
                  ComplaintStatus.open,
                  locale: 'en',
                ),
                WenshyStatusBadge.offer(OfferStatus.accepted, locale: 'en'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('تم التوصيل'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('WenshyPrimaryButton handles tap and loading states', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Scaffold(
            body: WenshyPrimaryButton(
              label: 'طلب ونش الآن',
              icon: Icons.local_shipping,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('طلب ونش الآن'));
      expect(tapped, isTrue);

      tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Scaffold(
            body: WenshyPrimaryButton(
              label: 'طلب ونش الآن',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('طلب ونش الآن'), findsNothing);
    });

    testWidgets('WenshyLoadingView and WenshyErrorView render RTL retry', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: WenshyTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: [
                  const WenshyLoadingView(message: 'جاري التحميل...'),
                  WenshyErrorView(
                    title: 'خطأ في الاتصال',
                    message: 'تعذر تحميل البيانات',
                    onRetry: () => retried = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('جاري التحميل...'), findsOneWidget);
      expect(find.text('خطأ في الاتصال'), findsOneWidget);
      expect(find.text('تعذر تحميل البيانات'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });
  });
}
