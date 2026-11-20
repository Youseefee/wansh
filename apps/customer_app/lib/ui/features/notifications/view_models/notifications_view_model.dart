import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/notification_repository.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for the in-app Notifications inbox (`public.notifications`),
/// tracking unread counts and subscribing to live Realtime inserts/updates.
class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    required this._repository,
  });

  final NotificationRepository _repository;

  NotificationRealtimeSubscription? _subscription;
  String? _activeUserId;
  bool _disposed = false;

  List<AppNotification> _notifications = const <AppNotification>[];
  bool _isLoading = false;
  bool _isMarkingAll = false;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isMarkingAll => _isMarkingAll;
  String? get errorMessage => _errorMessage;
  String? get activeUserId => _activeUserId;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Loads notifications for [userId] and subscribes to Realtime changes.
  Future<void> initialize(
    String userId, {
    String locale = 'ar',
    bool forceReload = false,
  }) async {
    if (!forceReload && _activeUserId == userId && _subscription != null) {
      return;
    }

    _activeUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      _notifications = await _repository.getNotifications(userId, limit: 50);
      _subscribe(userId);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Refreshes notifications from the server for the active user.
  Future<void> refresh({String? userId, String locale = 'ar'}) async {
    final uid = userId ?? _activeUserId;
    if (uid == null) return;
    _activeUserId = uid;
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      _notifications = await _repository.getNotifications(uid, limit: 50);
      if (_subscription == null) {
        _subscribe(uid);
      }
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Marks a single notification as read with optimistic UI update.
  Future<void> markAsRead(
    String notificationId, {
    String locale = 'ar',
  }) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx == -1 || _notifications[idx].isRead) return;

    final previous = _notifications;
    final updated = List<AppNotification>.from(_notifications);
    updated[idx] = updated[idx].copyWith(isRead: true);
    _notifications = List<AppNotification>.unmodifiable(updated);
    _safeNotify();

    try {
      await _repository.markAsRead(notificationId);
    } catch (e) {
      _notifications = previous;
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      _safeNotify();
    }
  }

  /// Marks all unread notifications for the active user as read.
  Future<void> markAllAsRead({String? userId, String locale = 'ar'}) async {
    final uid = userId ?? _activeUserId;
    if (uid == null || unreadCount == 0) return;

    final previous = _notifications;
    _isMarkingAll = true;
    _errorMessage = null;
    _notifications = List<AppNotification>.unmodifiable(
      _notifications.map((n) => n.isRead ? n : n.copyWith(isRead: true)),
    );
    _safeNotify();

    try {
      await _repository.markAllAsRead(uid);
    } catch (e) {
      _notifications = previous;
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isMarkingAll = false;
      _safeNotify();
    }
  }

  /// Clears state and unsubscribes on sign-out.
  void clear() {
    _activeUserId = null;
    _notifications = const <AppNotification>[];
    _errorMessage = null;
    _isLoading = false;
    unawaited(_subscription?.dispose());
    _subscription = null;
    _safeNotify();
  }

  void _subscribe(String userId) {
    unawaited(_subscription?.dispose());
    _subscription = _repository.subscribeToNotifications(
      userId: userId,
      onInsert: _handleInsert,
      onUpdate: _handleUpdate,
    );
  }

  void _handleInsert(AppNotification notification) {
    if (_disposed) return;
    final existingIdx = _notifications.indexWhere((n) => n.id == notification.id);
    if (existingIdx != -1) {
      _handleUpdate(notification);
      return;
    }
    _notifications = List<AppNotification>.unmodifiable(
      <AppNotification>[notification, ..._notifications],
    );
    _safeNotify();
  }

  void _handleUpdate(AppNotification notification) {
    if (_disposed) return;
    final idx = _notifications.indexWhere((n) => n.id == notification.id);
    if (idx == -1) {
      _handleInsert(notification);
      return;
    }
    final next = List<AppNotification>.from(_notifications);
    next[idx] = notification;
    _notifications = List<AppNotification>.unmodifiable(next);
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.dispose());
    _subscription = null;
    super.dispose();
  }
}
