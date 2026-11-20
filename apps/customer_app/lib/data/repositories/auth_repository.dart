import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Contract for customer authentication and profile management.
abstract class AuthRepository {
  Session? get currentSession;
  User? get currentUser;
  String? get currentUserId;
  Stream<AuthState> get onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String locale = 'ar',
  });

  Future<void> sendPasswordResetEmail(String email, {String? redirectTo});

  Future<void> signInWithPhoneOtp(String phone);

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  });

  Future<void> deleteMyAccount({String? reason});

  Future<void> signOut();
  Future<UserProfile?> getCurrentProfile();

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? fcmToken,
    String? locale,
  });
}

/// Supabase-backed [AuthRepository] delegating to [AuthService] from
/// `wenshy_core`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({AuthService? authService})
      : _authService = authService ?? const AuthService();

  final AuthService _authService;

  @override
  Session? get currentSession => _authService.currentSession;

  @override
  User? get currentUser => _authService.currentUser;

  @override
  String? get currentUserId => _authService.currentUserId;

  @override
  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _authService.signInWithEmail(email: email, password: password);

  @override
  Future<AuthResponse> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String locale = 'ar',
  }) =>
      _authService.signUpCustomer(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        locale: locale,
      );

  @override
  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) =>
      _authService.sendPasswordResetEmail(email, redirectTo: redirectTo);

  @override
  Future<void> signInWithPhoneOtp(String phone) =>
      _authService.signInWithPhoneOtp(phone);

  @override
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) =>
      _authService.verifyPhoneOtp(phone: phone, token: token);

  @override
  Future<void> deleteMyAccount({String? reason}) =>
      _authService.deleteMyAccount(reason: reason);

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<UserProfile?> getCurrentProfile() => _authService.getCurrentProfile();

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? fcmToken,
    String? locale,
  }) =>
      _authService.updateProfile(
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
        fcmToken: fcmToken,
        locale: locale,
      );
}
