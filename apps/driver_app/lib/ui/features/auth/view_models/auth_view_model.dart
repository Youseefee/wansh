import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/repositories/driver_auth_repository.dart';
import '../../../core/driver_session_controller.dart';
import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';

/// ViewModel backing Driver Login (Email/Password, Forgot Password, Phone OTP)
/// and Driver Registration screens.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required this._authRepository,
    required this._sessionController,
    required this._localeController,
  });

  final DriverAuthRepository _authRepository;
  final DriverSessionController _sessionController;
  final LocaleController _localeController;

  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _registrationNeedsEmailConfirm = false;
  bool _otpSent = false;
  String? _pendingOtpPhone;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  bool get registrationNeedsEmailConfirm => _registrationNeedsEmailConfirm;
  bool get otpSent => _otpSent;
  String? get pendingOtpPhone => _pendingOtpPhone;

  void clearError() {
    if (_errorMessage == null &&
        _infoMessage == null &&
        !_registrationNeedsEmailConfirm) {
      return;
    }
    _errorMessage = null;
    _infoMessage = null;
    _registrationNeedsEmailConfirm = false;
    notifyListeners();
  }

  void resetOtpFlow() {
    _otpSent = false;
    _pendingOtpPhone = null;
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
    _registrationNeedsEmailConfirm = false;
    notifyListeners();

    try {
      await _authRepository.signInWithEmail(email: email, password: password);
      await _sessionController.refreshSession();
      return true;
    } catch (e) {
      _errorMessage = _localizeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authRepository.sendPasswordResetEmail(email.trim());
      _infoMessage = DriverStrings.passwordResetSent(
        _localeController.localeCode,
      );
      return true;
    } catch (e) {
      _errorMessage = _localizeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPhoneOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      final trimmed = phone.trim();
      await _authRepository.signInWithPhoneOtp(trimmed);
      _otpSent = true;
      _pendingOtpPhone = trimmed;
      _infoMessage = DriverStrings.otpSentSuccess(_localeController.localeCode);
      return true;
    } catch (e) {
      _errorMessage = _localizeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authRepository.verifyPhoneOtp(
        phone: phone.trim(),
        token: token.trim(),
      );
      await _sessionController.refreshSession();
      _otpSent = false;
      _pendingOtpPhone = null;
      return true;
    } catch (e) {
      _errorMessage = _localizeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String nationalIdNumber,
    required String licenseNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _infoMessage = null;
    _registrationNeedsEmailConfirm = false;
    notifyListeners();

    try {
      final result = await _authRepository.registerDriver(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        nationalIdNumber: nationalIdNumber,
        licenseNumber: licenseNumber,
        locale: _localeController.localeCode,
      );

      if (result.requiresEmailVerification) {
        _registrationNeedsEmailConfirm = true;
        return false;
      }

      await _sessionController.refreshSession();
      return true;
    } catch (e) {
      _errorMessage = _localizeError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _localizeError(Object error) {
    final locale = _localeController.localeCode;
    if (error is DriverAuthFailure) {
      return switch (error.code) {
        'invalid_role' => DriverStrings.t(
            locale,
            'هذا التطبيق مخصص لسائقي الأوناش فقط.',
            'This app is restricted to tow-truck drivers.',
          ),
        'account_inactive' => DriverStrings.t(
            locale,
            'هذا الحساب موقوف حالياً. تواصل مع الدعم.',
            'This account is inactive. Please contact support.',
          ),
        _ => DriverStrings.t(
            locale,
            'تعذر تحميل ملف السائق.',
            'Unable to load driver profile.',
          ),
      };
    }
    if (error is AuthException) {
      return error.message;
    }
    return DriverStrings.t(
      locale,
      'حدث خطأ غير متوقع. تحقق من الاتصال وحاول مجدداً.',
      'An unexpected error occurred. Please check your connection and try again.',
    );
  }
}
