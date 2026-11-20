import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/driver_notification_repository.dart';
import '../../../core/driver_session_controller.dart';

/// Shared state holder for the driver's in-app notifications inbox and live
/// unread counter badge (backed by `public.notifications` + Realtime).
class DriverNotificationsController extends ChangeNotifier {
  DriverNotificationsController({
    required this._notificationRepository,
    required this._sessionController,
    this._autoSyncWithSession = true,
  }) {
    if (_autoSyncWithSession) {
      _sessionController.addListener(_onSessionChanged);
      _onSessionChanged();
    }
  }

  final DriverNotificationRepository _notificationRepository;
  final DriverSessionController _sessionController;
  final bool _autoSyncWithSession;

  StreamSubscription<AppNotification>? _realtimeSub;
  String? _boundUserId;

  bool _isLoading = false;
  bool _isMarkingAll = false;
  List<AppNotification> _notifications = const <AppNotification>[];
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isMarkingAll => _isMarkingAll;
  List<AppNotification> get notifications => _notifications;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  void _onSessionChanged() {
    final userId = _sessionController.isAuthenticated
        ? _sessionController.userProfile?.id
        : null;
    if (userId == _boundUserId) return;

    if (userId == null) {
      _clear();
      return;
    }

    _boundUserId = userId;
    unawaited(loadNotifications(userId: userId));
    _subscribeRealtime(userId);
  }

  Future<void> loadNotifications({String? userId}) async {
    final targetUserId = userId ?? _sessionController.userProfile?.id;
    if (targetUserId == null) {
      _clear();
      return;
    }

    if (_boundUserId != targetUserId) {
      _boundUserId = targetUserId;
      _subscribeRealtime(targetUserId);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _notificationRepository.getNotifications(
        targetUserId,
      );
      _notifications = List<AppNotification>.unmodifiable(fetched);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeRealtime(String userId) {
    unawaited(_realtimeSub?.cancel());
    _realtimeSub =
        _notificationRepository.watchNotifications(userId).listen((item) {
      _upsertNotification(item);
    });
  }

  void _upsertNotification(AppNotification item) {
    final mutable = List<AppNotification>.from(_notifications);
    final idx = mutable.indexWhere((n) => n.id == item.id);
    if (idx >= 0) {
      mutable[idx] = item;
    } else {
      mutable.insert(0, item);
    }
    mutable.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _notifications = List<AppNotification>.unmodifiable(mutable);
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx == -1 || _notifications[idx].isRead) return;

    final previous = _notifications;
    final mutable = List<AppNotification>.from(_notifications);
    mutable[idx] = mutable[idx].copyWith(isRead: true);
    _notifications = List<AppNotification>.unmodifiable(mutable);
    notifyListeners();

    try {
      await _notificationRepository.markAsRead(notificationId);
    } catch (e) {
      _notifications = previous;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _boundUserId ?? _sessionController.userProfile?.id;
    if (userId == null || !hasUnread || _isMarkingAll) return;

    final previous = _notifications;
    _isMarkingAll = true;
    _errorMessage = null;
    _notifications = List<AppNotification>.unmodifiable(
      _notifications.map((n) => n.isRead ? n : n.copyWith(isRead: true)),
    );
    notifyListeners();

    try {
      await _notificationRepository.markAllAsRead(userId);
    } catch (e) {
      _notifications = previous;
      _errorMessage = e.toString();
    } finally {
      _isMarkingAll = false;
      notifyListeners();
    }
  }

  void _clear() {
    _boundUserId = null;
    unawaited(_realtimeSub?.cancel());
    _realtimeSub = null;
    _notifications = const <AppNotification>[];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_autoSyncWithSession) {
      _sessionController.removeListener(_onSessionChanged);
    }
    unawaited(_realtimeSub?.cancel());
    unawaited(_notificationRepository.disposeSubscriptions());
    super.dispose();
  }
}
