import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/notification_repository.dart';

/// Abstracts native push notification token retrieval (e.g. Firebase Cloud
/// Messaging) so FCM can be wired cleanly once `google-services.json` /
/// `GoogleService-Info.plist` is configured, without crashing when Firebase is
/// absent.
abstract class PushTokenProvider {
  /// Returns the current device push token, or `null` if push messaging is not
  /// configured or permission was denied.
  Future<String?> getToken();

  /// One of `'android'`, `'ios'`, or `'web'`.
  String get platform;

  /// Emits refreshed tokens when the underlying push SDK rotates them.
  Stream<String> get onTokenRefresh;
}

/// Safe default [PushTokenProvider] used before Firebase is configured.
///
/// Replace with an FCM-backed implementation once `firebase_core` +
/// `firebase_messaging` and `google-services.json` are added.
class SafeNoopPushTokenProvider implements PushTokenProvider {
  const SafeNoopPushTokenProvider();

  @override
  Future<String?> getToken() async => null;

  @override
  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
  }

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
}

/// Coordinates registering and deactivating push tokens in
/// `public.device_tokens` on login and sign-out.
class PushTokenRegistrar {
  PushTokenRegistrar({
    required this._notificationRepository,
    PushTokenProvider? tokenProvider,
  }) : _tokenProvider = tokenProvider ?? const SafeNoopPushTokenProvider();

  final NotificationRepository _notificationRepository;
  final PushTokenProvider _tokenProvider;

  StreamSubscription<String>? _refreshSub;
  String? _activeUserId;
  String? _registeredToken;

  String? get registeredToken => _registeredToken;

  /// Safely fetches and upserts the current device token for [userId].
  /// Never throws so authentication flow is never blocked when push is
  /// unconfigured or offline.
  Future<void> registerForUser(String userId) async {
    _activeUserId = userId;
    try {
      final token = await _tokenProvider.getToken();
      if (token != null && token.trim().isNotEmpty) {
        final cleaned = token.trim();
        await _notificationRepository.upsertDeviceToken(
          userId: userId,
          token: cleaned,
          platform: _tokenProvider.platform,
        );
        _registeredToken = cleaned;
      }

      await _refreshSub?.cancel();
      _refreshSub = _tokenProvider.onTokenRefresh.listen((newToken) {
        final uid = _activeUserId;
        final cleaned = newToken.trim();
        if (uid == null || cleaned.isEmpty) return;
        _registeredToken = cleaned;
        unawaited(
          _notificationRepository
              .upsertDeviceToken(
                userId: uid,
                token: cleaned,
                platform: _tokenProvider.platform,
              )
              .catchError((_) {}),
        );
      });
    } catch (_) {
      // Push token registration is best-effort and must never break login.
    }
  }

  /// Deactivates the last registered token on sign-out or account deletion.
  Future<void> unregisterCurrentToken() async {
    final token = _registeredToken;
    _activeUserId = null;
    _registeredToken = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (token == null || token.isEmpty) return;
    try {
      await _notificationRepository.deactivateDeviceToken(token);
    } catch (_) {
      // Ignore network/RLS errors on logout cleanup.
    }
  }

  void dispose() {
    unawaited(_refreshSub?.cancel());
    _refreshSub = null;
  }
}
