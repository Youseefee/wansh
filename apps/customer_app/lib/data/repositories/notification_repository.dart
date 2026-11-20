import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Handle representing an active Realtime subscription to `public.notifications`.
abstract class NotificationRealtimeSubscription {
  Future<void> dispose();
}

/// Repository for in-app notifications (`public.notifications`) and device
/// push tokens (`public.device_tokens`).
abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  });

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead(String userId);

  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  });

  Future<void> deactivateDeviceToken(String token);

  NotificationRealtimeSubscription subscribeToNotifications({
    required String userId,
    required void Function(AppNotification notification) onInsert,
    required void Function(AppNotification notification) onUpdate,
  });
}

class _SupabaseNotificationSubscription
    implements NotificationRealtimeSubscription {
  _SupabaseNotificationSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  Future<void> dispose() async {
    await _client.removeChannel(_channel);
  }
}

/// Supabase-backed [NotificationRepository] delegating CRUD to
/// [NotificationService] from `wenshy_core` and listening to Realtime changes.
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({
    SupabaseClient? client,
    NotificationService? notificationService,
  })  : _client = client,
        _service = notificationService ?? NotificationService(client: client);

  final SupabaseClient? _client;
  final NotificationService _service;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  }) =>
      _service.getNotifications(userId, limit: limit);

  @override
  Future<void> markAsRead(String notificationId) =>
      _service.markAsRead(notificationId);

  @override
  Future<void> markAllAsRead(String userId) => _service.markAllAsRead(userId);

  @override
  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) =>
      _service.upsertDeviceToken(
        userId: userId,
        token: token,
        platform: platform,
      );

  @override
  Future<void> deactivateDeviceToken(String token) =>
      _service.deactivateDeviceToken(token);

  @override
  NotificationRealtimeSubscription subscribeToNotifications({
    required String userId,
    required void Function(AppNotification notification) onInsert,
    required void Function(AppNotification notification) onUpdate,
  }) {
    final channel = _supabase.channel('notifications:$userId');
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
          callback: (payload) {
            try {
              final record = Map<String, dynamic>.from(payload.newRecord);
              if (record.containsKey('id')) {
                onInsert(AppNotification.fromJson(record));
              }
            } catch (_) {
              // Ignore malformed realtime payloads.
            }
          },
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
          callback: (payload) {
            try {
              final record = Map<String, dynamic>.from(payload.newRecord);
              if (record.containsKey('id')) {
                onUpdate(AppNotification.fromJson(record));
              }
            } catch (_) {
              // Ignore malformed realtime payloads.
            }
          },
        )
        .subscribe();

    return _SupabaseNotificationSubscription(_supabase, channel);
  }
}
