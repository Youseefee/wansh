import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';

void main() {
  const timestamp = '2026-11-20T14:30:00.000Z';

  group('AppNotification model', () {
    test('fromJson / toJson round-trip and localization helpers', () {
      final json = <String, dynamic>{
        'id': 'notif-1',
        'user_id': 'user-1',
        'title_ar': 'تم قبول طلب الإنقاذ',
        'title_en': 'Rescue Request Accepted',
        'body_ar': 'السائق أحمد في الطريق إليك الآن.',
        'body_en': 'Driver Ahmed is on the way to your location.',
        'type': 'trip_status',
        'data': <String, dynamic>{
          'request_id': 'req-42',
          'status': 'driver_assigned',
        },
        'is_read': false,
        'created_at': timestamp,
      };

      final notification = AppNotification.fromJson(json);
      expect(notification.id, 'notif-1');
      expect(notification.userId, 'user-1');
      expect(notification.type, 'trip_status');
      expect(notification.data['request_id'], 'req-42');
      expect(notification.isRead, isFalse);

      expect(notification.localizedTitle('ar'), 'تم قبول طلب الإنقاذ');
      expect(notification.localizedTitle('ar_EG'), 'تم قبول طلب الإنقاذ');
      expect(notification.localizedTitle('en'), 'Rescue Request Accepted');
      expect(notification.localizedBody('ar'), 'السائق أحمد في الطريق إليك الآن.');
      expect(
        notification.localizedBody('en'),
        'Driver Ahmed is on the way to your location.',
      );

      expect(AppNotification.fromJson(notification.toJson()), notification);

      final read = notification.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read, isNot(notification));
    });

    test('falls back to alternate language when preferred string is empty', () {
      final notification = AppNotification(
        id: 'notif-2',
        userId: 'user-1',
        titleAr: '',
        titleEn: 'Account Approved',
        bodyAr: 'تم اعتماد حسابك',
        bodyEn: '',
        type: 'driver_approval',
        createdAt: DateTime.parse(timestamp),
      );

      expect(notification.localizedTitle('ar'), 'Account Approved');
      expect(notification.localizedBody('en'), 'تم اعتماد حسابك');
    });

    test('handles null data payload safely', () {
      final notification = AppNotification.fromJson(const <String, dynamic>{
        'id': 'notif-3',
        'user_id': 'user-1',
        'title_ar': 'إشعار',
        'title_en': 'Notice',
        'body_ar': 'تفاصيل',
        'body_en': 'Details',
        'type': 'general',
        'data': null,
        'is_read': true,
        'created_at': timestamp,
      });

      expect(notification.data, isEmpty);
      expect(notification.isRead, isTrue);
    });
  });

  group('NotificationService validation', () {
    test('rejects blank token and unsupported platform before hitting backend', () async {
      const service = NotificationService();

      await expectLater(
        service.upsertDeviceToken(
          userId: 'user-1',
          token: '   ',
          platform: 'android',
        ),
        throwsArgumentError,
      );

      await expectLater(
        service.upsertDeviceToken(
          userId: 'user-1',
          token: 'fcm-token-123',
          platform: 'desktop',
        ),
        throwsArgumentError,
      );
    });
  });
}
