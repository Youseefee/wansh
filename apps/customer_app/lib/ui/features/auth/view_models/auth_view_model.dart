import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../core/error_formatter.dart';
import '../../../core/locale_controller.dart';
import '../../../core/push_token_service.dart';

/// Manages customer authentication state, session listening, registration,
/// password reset, phone OTP login, account deletion, push-token hook, and
/// `public.profiles` loading/updating.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required this._repository,
    required this._localeController,
    this._pushTokenRegistrar,
    bool autoListen = true,
  }) {
    _isAuthenticated = _repository.currentSession != null;
    if (autoListen) {
      _authSubscription = _repository.onAuthStateChange.listen((authState) {
        final signedIn = authState.session != null;
        final changed = _isAuthenticated != signedIn;
        _isAuthenticated = signedIn;
        if (signedIn) {
          unawaited(loadProfile(syncLocale: true));
          final uid = authState.session?.user.id;
          if (uid != null) {
            unawaited(_pushTokenRegistrar?.registerForUser(uid));
          }
        } else {
          _profile = null;
          if (changed) notifyListeners();
        }
        if (changed) notifyListeners();
      });
    }
    if (_isAuthenticated) {
      unawaited(loadProfile(syncLocale: true));
      final uid = _repository.currentUserId;
      if (uid != null) {
        unawaited(_pushTokenRegistrar?.registerForUser(uid));
      }
    }
  }

  final AuthRepository _repository;
  final LocaleController _localeController;
  final PushTokenRegistrar? _pushTokenRegistrar;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isSavingProfile = false;
  bool _isDeletingAccount = false;
  String? _otpSentPhone;
  UserProfile? _profile;
  String? _errorMessage;
  String? _infoMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isSavingProfile => _isSavingProfile;
  bool get isDeletingAccount => _isDeletingAccount;
  String? get otpSentPhone => _otpSentPhone;
  bool get isAwaitingOtpVerification => _otpSentPhone != null;
  UserProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get currentUserId => _profile?.id ?? _repository.currentUserId;

  bool get isNonCustomerAccount =>
      _profile != null && _profile!.role != AppRole.customer;

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      _isAuthenticated = response.session != null || _repository.currentSession != null;
      if (_isAuthenticated) {
        await loadProfile(syncLocale: true);
        final uid = currentUserId;
        if (uid != null) {
          await _pushTokenRegistrar?.registerForUser(uid);
        }
      }
      return _isAuthenticated;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a password reset email via `AuthService.sendPasswordResetEmail`.
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _repository.sendPasswordResetEmail(email.trim());
      _infoMessage = _localeController.isArabic
          ? 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.'
          : 'Password reset link sent to your email.';
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends an SMS OTP to [phone] via `AuthService.signInWithPhoneOtp`.
  Future<bool> sendPhoneOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final trimmed = phone.trim();
      await _repository.signInWithPhoneOtp(trimmed);
      _otpSentPhone = trimmed;
      _infoMessage = _localeController.isArabic
          ? 'تم إرسال رمز التحقق عبر رسالة نصية إلى هاتفك.'
          : 'A verification code has been sent via SMS to your phone.';
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifies an SMS OTP [token] for [phone] and signs the customer in.
  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final response = await _repository.verifyPhoneOtp(
        phone: phone.trim(),
        token: token.trim(),
      );
      _isAuthenticated =
          response.session != null || _repository.currentSession != null;
      if (_isAuthenticated) {
        _otpSentPhone = null;
        await loadProfile(syncLocale: true);
        final uid = currentUserId;
        if (uid != null) {
          await _pushTokenRegistrar?.registerForUser(uid);
        }
      }
      return _isAuthenticated;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetPhoneOtpFlow() {
    _otpSentPhone = null;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final response = await _repository.signUpCustomer(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        locale: _localeController.languageCode,
      );
      _isAuthenticated = response.session != null;
      if (_isAuthenticated) {
        await loadProfile(syncLocale: false);
        final uid = currentUserId;
        if (uid != null) {
          await _pushTokenRegistrar?.registerForUser(uid);
        }
      } else {
        _infoMessage = _localeController.isArabic
            ? 'تم إنشاء الحساب! يرجى تأكيد البريد الإلكتروني ثم تسجيل الدخول.'
            : 'Account created! Please check your email and sign in.';
      }
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile({bool syncLocale = false}) async {
    try {
      final loaded = await _repository.getCurrentProfile();
      _profile = loaded;
      if (syncLocale && loaded != null) {
        _localeController.setLanguageCode(loaded.locale);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    _isSavingProfile = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateProfile(
        fullName: fullName,
        phone: phone,
        locale: _localeController.languageCode,
      );
      _profile = updated;
      _infoMessage = _localeController.isArabic
          ? 'تم تحديث الملف الشخصي بنجاح'
          : 'Profile updated successfully';
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
      return false;
    } finally {
      _isSavingProfile = false;
      notifyListeners();
    }
  }

  Future<void> toggleLanguageAndSync() async {
    final nextCode = _localeController.toggleLocale();
    if (_isAuthenticated) {
      try {
        _profile = await _repository.updateProfile(locale: nextCode);
        notifyListeners();
      } catch (_) {
        // UI language toggle still applies locally if offline.
      }
    }
  }

  /// Requests account deletion via `public.delete_my_account` RPC and signs
  /// out the current session. Displays a friendly error if blocked by an
  /// active trip.
  Future<bool> deleteMyAccount({String? reason}) async {
    _isDeletingAccount = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _repository.deleteMyAccount(reason: reason);
      await _pushTokenRegistrar?.unregisterCurrentToken();
      _isAuthenticated = false;
      _profile = null;
      _otpSentPhone = null;
      _infoMessage = _localeController.isArabic
          ? 'تم حذف حسابك بنجاح.'
          : 'Your account has been deleted.';
      return true;
    } catch (e) {
      final raw = e.toString().toLowerCase();
      final isActiveTripError = raw.contains('active') ||
          raw.contains('in-progress') ||
          raw.contains('in_progress') ||
          raw.contains('p0001') ||
          raw.contains('trip');
      if (isActiveTripError) {
        _errorMessage = _localeController.isArabic
            ? 'لا يمكنك حذف حسابك أثناء وجود رحلة إنقاذ نشطة. يرجى إنهاء الرحلة أو إلغاؤها أولاً.'
            : 'You cannot delete your account while you have an active rescue trip. Please complete or cancel it first.';
      } else {
        _errorMessage = ErrorFormatter.format(
          e,
          locale: _localeController.languageCode,
        );
      }
      return false;
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _pushTokenRegistrar?.unregisterCurrentToken();
      await _repository.signOut();
      _isAuthenticated = false;
      _profile = null;
      _otpSentPhone = null;
      _errorMessage = null;
      _infoMessage = null;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(
        e,
        locale: _localeController.languageCode,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
