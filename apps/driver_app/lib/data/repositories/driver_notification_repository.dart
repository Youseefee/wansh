import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Repository wrapping `public.notifications` (CRUD + Realtime) and
/// `public.device_tokens` registration via `wenshy_core`'s [NotificationService].
abstract class DriverNotificationRepository {
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  });

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead(String userId);

  Stream<AppNotification> watchNotifications(String userId);

  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  });

  Future<void> deactivateDeviceToken(String token);

  Future<void> disposeSubscriptions();
}

/// Supabase-backed implementation of [DriverNotificationRepository].
class SupabaseDriverNotificationRepository
    implements DriverNotificationRepository {
  SupabaseDriverNotificationRepository({
    SupabaseClient? client,
    NotificationService? notificationService,
  })  : _supabase = client ?? Supabase.instance.client,
        _notificationService =
            notificationService ?? NotificationService(client: client);

  final SupabaseClient _supabase;
  final NotificationService _notificationService;

  RealtimeChannel? _notificationsChannel;
  StreamController<AppNotification>? _notificationsController;
  String? _subscribedUserId;

  @override
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  }) {
    return _notificationService.getNotifications(userId, limit: limit);
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _notificationService.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) {
    return _notificationService.markAllAsRead(userId);
  }

  @override
  Stream<AppNotification> watchNotifications(String userId) {
    if (_subscribedUserId == userId &&
        _notificationsController != null &&
        !_notificationsController!.isClosed) {
      return _notificationsController!.stream;
    }

    unawaited(_teardownChannel());
    final controller = StreamController<AppNotification>.broadcast();
    _notificationsController = controller;
    _subscribedUserId = userId;

    void handleChange(PostgresChangePayload payload) {
      final record = payload.newRecord;
      if (record.isEmpty) return;
      try {
        final item = AppNotification.fromJson(
          Map<String, dynamic>.from(record),
        );
        if (!controller.isClosed) {
          controller.add(item);
        }
      } catch (_) {
        // Ignore malformed Realtime payloads safely.
      }
    }

    final channel = _supabase.channel('driver-notifications:$userId');
    _notificationsChannel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: WenshyTables.notifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: handleChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: WenshyTables.notifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: handleChange,
        )
        .subscribe();

    return controller.stream;
  }

  @override
  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) {
    return _notificationService.upsertDeviceToken(
      userId: userId,
      token: token,
      platform: platform,
    );
  }

  @override
  Future<void> deactivateDeviceToken(String token) {
    return _notificationService.deactivateDeviceToken(token);
  }

  Future<void> _teardownChannel() async {
    final channel = _notificationsChannel;
    _notificationsChannel = null;
    _subscribedUserId = null;
    if (channel != null) {
      await _supabase.removeChannel(channel);
    }
    final controller = _notificationsController;
    _notificationsController = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> disposeSubscriptions() => _teardownChannel();
}
