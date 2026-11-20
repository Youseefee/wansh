import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Result returned after driver registration.
class DriverSignUpResult {
  const DriverSignUpResult({
    required this.requiresEmailVerification,
    this.userId,
  });

  final bool requiresEmailVerification;
  final String? userId;
}

/// Exception thrown for driver-specific auth constraints (e.g. non-driver role
/// attempting to sign into the Driver App).
class DriverAuthFailure implements Exception {
  const DriverAuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DriverAuthFailure($code): $message';
}

/// Authentication & driver profile data repository.
abstract class DriverAuthRepository {
  String? get currentUserId;
  Stream<AuthState> get onAuthStateChange;

  Future<UserProfile?> getCurrentProfile();
  Future<DriverProfile?> getDriverProfile();
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<DriverSignUpResult> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String nationalIdNumber,
    required String licenseNumber,
    required String locale,
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signInWithPhoneOtp(String phone);
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  });
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
  });
  Future<UserProfile> updateLocale(String locale);
  Future<void> deleteMyAccount({String? reason});
  Future<void> signOut();
}

/// Supabase-backed implementation of [DriverAuthRepository].
class SupabaseDriverAuthRepository implements DriverAuthRepository {
  SupabaseDriverAuthRepository({
    SupabaseClient? client,
    AuthService? authService,
  })  : _supabase = client ?? Supabase.instance.client,
        _authService = authService ?? AuthService(client: client);

  final SupabaseClient _supabase;
  final AuthService _authService;

  @override
  String? get currentUserId => _authService.currentUserId;

  @override
  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  @override
  Future<UserProfile?> getCurrentProfile() => _authService.getCurrentProfile();

  @override
  Future<DriverProfile?> getDriverProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    // Disambiguate `drivers.id -> profiles.id` because `drivers.reviewed_by`
    // also references `public.profiles(id)` (`PGRST201` otherwise).
    final row = await _supabase
        .from(WenshyTables.drivers)
        .select('*, profiles!drivers_id_fkey(*)')
        .eq('id', uid)
        .maybeSingle();

    if (row == null) return null;
    return DriverProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> _ensureDriverAccountAccess() async {
    final profile = await getCurrentProfile();
    if (profile == null) {
      await _authService.signOut();
      throw const DriverAuthFailure(
        'missing_profile',
        'User profile could not be loaded.',
      );
    }
    if (profile.role != AppRole.driver) {
      await _authService.signOut();
      throw const DriverAuthFailure(
        'invalid_role',
        'This application is restricted to Wenshy tow-truck drivers.',
      );
    }
    if (!profile.isActive) {
      await _authService.signOut();
      throw const DriverAuthFailure(
        'account_inactive',
        'This account is inactive.',
      );
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _authService.signInWithEmail(email: email, password: password);
    await _ensureDriverAccountAccess();
  }

  @override
  Future<DriverSignUpResult> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String nationalIdNumber,
    required String licenseNumber,
    required String locale,
  }) async {
    final response = await _authService.signUpDriver(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      nationalIdNumber: nationalIdNumber,
      licenseNumber: licenseNumber,
      locale: locale,
    );

    return DriverSignUpResult(
      requiresEmailVerification: response.session == null,
      userId: response.user?.id,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) {
    return _authService.signInWithPhoneOtp(phone);
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _authService.verifyPhoneOtp(phone: phone, token: token);
    await _ensureDriverAccountAccess();
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
  }) {
    return _authService.updateProfile(
      fullName: fullName,
      phone: phone,
    );
  }

  @override
  Future<UserProfile> updateLocale(String locale) {
    return _authService.updateProfile(locale: locale);
  }

  @override
  Future<void> deleteMyAccount({String? reason}) {
    return _authService.deleteMyAccount(reason: reason);
  }

  @override
  Future<void> signOut() => _authService.signOut();
}
