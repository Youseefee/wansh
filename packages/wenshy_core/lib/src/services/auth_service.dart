import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';

/// Shared authentication & profile service backed by Supabase Auth and
/// `public.profiles`.
class AuthService {
  const AuthService({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Active session if signed in.
  Session? get currentSession => _supabase.auth.currentSession;

  /// Active Supabase Auth user if signed in.
  User? get currentUser => _supabase.auth.currentUser;

  /// Authenticated user UUID or `null`.
  String? get currentUserId => currentUser?.id;

  /// Stream of auth state transitions (`signedIn`, `signedOut`, etc.).
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// Signs in an existing user using email & password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new customer account.
  ///
  /// The database trigger `private.handle_new_user()` reads `role`,
  /// `full_name`, `phone`, and `locale` from user metadata to populate
  /// `public.profiles`.
  Future<AuthResponse> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String locale = 'ar',
  }) {
    return _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        'role': 'customer',
        'full_name': fullName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'locale': locale == 'en' ? 'en' : 'ar',
      },
    );
  }

  /// Registers a new tow-truck driver account.
  ///
  /// The database trigger `private.handle_new_user()` creates both a
  /// `public.profiles` row (`role = 'driver'`) and a `public.drivers` row
  /// (`approval_status = 'pending'`) using these metadata fields.
  Future<AuthResponse> signUpDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String nationalIdNumber,
    required String licenseNumber,
    String locale = 'ar',
  }) {
    return _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{
        'role': 'driver',
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'national_id_number': nationalIdNumber.trim(),
        'license_number': licenseNumber.trim(),
        'locale': locale == 'en' ? 'en' : 'ar',
      },
    );
  }

  /// Sends a password reset link to [email].
  Future<void> sendPasswordResetEmail(String email, {String? redirectTo}) {
    return _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  /// Sends an SMS one-time passcode (OTP) to [phone].
  Future<void> signInWithPhoneOtp(String phone) {
    return _supabase.auth.signInWithOtp(phone: phone.trim());
  }

  /// Verifies an SMS OTP [token] sent to [phone] and establishes a session.
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    return _supabase.auth.verifyOTP(
      phone: phone.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  /// Requests account deletion via `public.delete_my_account` RPC and then
  /// signs out the current session.
  Future<void> deleteMyAccount({String? reason}) async {
    final trimmedReason = reason?.trim();
    await _supabase.rpc<dynamic>(
      WenshyRpcs.deleteMyAccount,
      params: <String, dynamic>{
        if (trimmedReason != null && trimmedReason.isNotEmpty)
          'p_reason': trimmedReason,
      },
    );
    await signOut();
  }

  /// Signs out the current user.
  Future<void> signOut() => _supabase.auth.signOut();

  /// Fetches the current user's `public.profiles` record, or `null` if
  /// signed out or missing.
  Future<UserProfile?> getCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final data = await _supabase
        .from(WenshyTables.profiles)
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }

  /// Updates editable fields on the signed-in user's `public.profiles` row.
  ///
  /// Note: `role` and `is_active` are protected by
  /// `trg_profiles_guard_updates` and cannot be edited by clients.
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? fcmToken,
    String? locale,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Cannot update profile when not authenticated.');
    }

    final payload = <String, dynamic>{
      if (fullName != null) 'full_name': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
      'avatar_url': ?avatarUrl,
      'fcm_token': ?fcmToken,
      if (locale != null) 'locale': locale == 'en' ? 'en' : 'ar',
    };

    if (payload.isEmpty) {
      final existing = await getCurrentProfile();
      if (existing == null) {
        throw StateError('Profile not found for user $uid.');
      }
      return existing;
    }

    final data = await _supabase
        .from(WenshyTables.profiles)
        .update(payload)
        .eq('id', uid)
        .select()
        .single();

    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }
}
