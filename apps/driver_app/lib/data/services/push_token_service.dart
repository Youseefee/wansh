import 'package:flutter/foundation.dart';

import '../repositories/driver_notification_repository.dart';

/// Provider for obtaining a push notification device token (e.g. FCM/APNs).
///
/// Defaults to returning `null` when Firebase Messaging is not configured yet
/// so app startup and authentication never crash.
abstract class DriverPushTokenProvider {
  Future<String?> getToken();
}

/// Safe no-op [DriverPushTokenProvider] used until Firebase Messaging is wired.
class NoOpDriverPushTokenProvider implements DriverPushTokenProvider {
  const NoOpDriverPushTokenProvider();

  @override
  Future<String?> getToken() async => null;
}

/// Registers and deactivates push device tokens for authenticated drivers
/// without crashing when Firebase or push permissions are unavailable.
class DriverPushTokenRegistrar {
  DriverPushTokenRegistrar({
    required this._notificationRepository,
    DriverPushTokenProvider? tokenProvider,
    this._platformOverride,
    this._isWebOverride,
  }) : _tokenProvider = tokenProvider ?? const NoOpDriverPushTokenProvider();

  final DriverNotificationRepository _notificationRepository;
  final DriverPushTokenProvider _tokenProvider;
  final TargetPlatform? _platformOverride;
  final bool? _isWebOverride;

  String? _lastRegisteredToken;
  String? _lastRegisteredUserId;

  String? get lastRegisteredToken => _lastRegisteredToken;

  /// Resolves the `device_tokens.platform` column value (`android`/`ios`/`web`),
  /// or `null` on unsupported desktop platforms.
  String? resolvePlatform() {
    if (_isWebOverride ?? kIsWeb) return 'web';
    final platform = _platformOverride ?? defaultTargetPlatform;
    return switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  /// Safely attempts to fetch and upsert the current device push token.
  /// Returns `true` if a token was registered, `false` otherwise.
  Future<bool> registerForUser(String userId) async {
    final platform = resolvePlatform();
    if (platform == null) return false;

    try {
      final token = (await _tokenProvider.getToken())?.trim();
      if (token == null || token.isEmpty) return false;

      if (_lastRegisteredToken == token && _lastRegisteredUserId == userId) {
        return true;
      }

      await _notificationRepository.upsertDeviceToken(
        userId: userId,
        token: token,
        platform: platform,
      );
      _lastRegisteredToken = token;
      _lastRegisteredUserId = userId;
      return true;
    } catch (_) {
      // Never block or crash driver authentication if push registration fails.
      return false;
    }
  }

  /// Clears in-memory token registration tracking without issuing a DB call
  /// (e.g. after server-side account deletion already deactivated tokens).
  void clearCachedToken() {
    _lastRegisteredToken = null;
    _lastRegisteredUserId = null;
  }

  /// Safely marks the last registered device token inactive on sign-out.
  Future<void> deactivateCurrentToken() async {
    final token = _lastRegisteredToken;
    clearCachedToken();
    if (token == null || token.isEmpty) return;
    try {
      await _notificationRepository.deactivateDeviceToken(token);
    } catch (_) {
      // Ignore transient errors during sign-out cleanup.
    }
  }
}
