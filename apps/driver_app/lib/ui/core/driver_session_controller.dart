import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../data/repositories/driver_auth_repository.dart';
import '../../data/repositories/driver_trip_repository.dart';
import '../../data/services/push_token_service.dart';
import 'locale_controller.dart';

enum DriverSessionStatus {
  initializing,
  unauthenticated,
  authenticated,
}

/// Global session & approval-gate state holder used by `GoRouter` redirects
/// and shared across driver features.
class DriverSessionController extends ChangeNotifier {
  DriverSessionController({
    required this._authRepository,
    required this._tripRepository,
    required this._localeController,
    this._pushTokenRegistrar,
    bool subscribeToAuthChanges = true,
  }) {
    if (subscribeToAuthChanges) {
      _authSub = _authRepository.onAuthStateChange.listen((authState) {
        if (authState.event == AuthChangeEvent.signedOut) {
          _clearSession();
        } else if (authState.event == AuthChangeEvent.signedIn ||
            authState.event == AuthChangeEvent.tokenRefreshed) {
          unawaited(refreshSession());
        }
      });
    }
  }

  final DriverAuthRepository _authRepository;
  final DriverTripRepository _tripRepository;
  final LocaleController _localeController;
  final DriverPushTokenRegistrar? _pushTokenRegistrar;

  StreamSubscription<AuthState>? _authSub;

  DriverSessionStatus _status = DriverSessionStatus.initializing;
  UserProfile? _userProfile;
  DriverProfile? _driverProfile;
  String? _activeTripId;
  String? _errorMessage;

  DriverSessionStatus get status => _status;
  UserProfile? get userProfile => _userProfile;
  DriverProfile? get driverProfile => _driverProfile;
  String? get activeTripId => _activeTripId;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == DriverSessionStatus.authenticated;
  bool get isApproved => _driverProfile?.isApproved ?? false;
  String? get driverId => _driverProfile?.id ?? _userProfile?.id;

  /// Loads initial authentication and driver approval state on startup.
  Future<void> initialize() async {
    _status = DriverSessionStatus.initializing;
    _errorMessage = null;
    notifyListeners();
    await refreshSession();
  }

  /// Refreshes the signed-in user's `profiles`, `drivers`, and active trip ID.
  Future<void> refreshSession() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) {
      _clearSession();
      return;
    }

    try {
      final profile = await _authRepository.getCurrentProfile();
      if (profile == null || profile.role != AppRole.driver || !profile.isActive) {
        await _authRepository.signOut();
        _clearSession(
          error: profile != null && profile.role != AppRole.driver
              ? 'invalid_role'
              : null,
        );
        return;
      }

      final driver = await _authRepository.getDriverProfile();
      RescueRequest? activeTrip;
      if (driver != null && driver.isApproved) {
        activeTrip = await _tripRepository.getActiveTrip(driver.id);
      }

      _userProfile = profile;
      _driverProfile = driver;
      _activeTripId = activeTrip?.id;
      _errorMessage = null;
      _status = DriverSessionStatus.authenticated;
      _localeController.applyLocaleSilently(profile.locale);
      if (_pushTokenRegistrar != null) {
        unawaited(_pushTokenRegistrar.registerForUser(profile.id));
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _status = _userProfile != null
          ? DriverSessionStatus.authenticated
          : DriverSessionStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Updates editable driver profile fields in `public.profiles` and refreshes
  /// the cached session state.
  Future<UserProfile> updateUserProfile({
    required String fullName,
    required String phone,
  }) async {
    final updated = await _authRepository.updateProfile(
      fullName: fullName.trim(),
      phone: phone.trim(),
    );
    _userProfile = updated;
    if (_driverProfile != null) {
      _driverProfile = _driverProfile!.copyWith(profile: updated);
    }
    notifyListeners();
    await refreshSession();
    return _userProfile ?? updated;
  }

  /// Requests account deletion via `delete_my_account` RPC and clears session.
  ///
  /// Throws if the backend rejects deletion (e.g., an active in-progress trip),
  /// leaving the current session and registered device push token intact.
  /// On success, the `delete_my_account` SQL RPC atomically deactivates all
  /// `device_tokens` for the user before sign-out.
  Future<void> deleteAccount({String? reason}) async {
    await _authRepository.deleteMyAccount(reason: reason);
    _pushTokenRegistrar?.clearCachedToken();
    _clearSession();
  }

  /// Updates the cached [DriverProfile] without waiting for a full reload.
  void updateDriverProfileCache(DriverProfile updated) {
    _driverProfile = updated;
    notifyListeners();
  }

  /// Updates the cached [activeTripId].
  void setActiveTripId(String? requestId) {
    if (_activeTripId == requestId) return;
    _activeTripId = requestId;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _pushTokenRegistrar?.deactivateCurrentToken();
    await _authRepository.signOut();
    _clearSession();
  }

  void _clearSession({String? error}) {
    _userProfile = null;
    _driverProfile = null;
    _activeTripId = null;
    _errorMessage = error;
    _status = DriverSessionStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }
}
