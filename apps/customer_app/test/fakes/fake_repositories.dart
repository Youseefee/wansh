import 'dart:async';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'package:wenshy_customer/data/repositories/auth_repository.dart';
import 'package:wenshy_customer/data/repositories/feedback_repository.dart';
import 'package:wenshy_customer/data/repositories/map_and_quote_repository.dart';
import 'package:wenshy_customer/data/repositories/models.dart';
import 'package:wenshy_customer/data/repositories/notification_repository.dart';
import 'package:wenshy_customer/data/repositories/rescue_request_repository.dart';
import 'package:wenshy_customer/data/repositories/vehicle_repository.dart';
import 'package:wenshy_customer/ui/core/app_dependencies.dart';
import 'package:wenshy_customer/ui/core/locale_controller.dart';
import 'package:wenshy_customer/ui/core/phone_dialer.dart';
import 'package:wenshy_customer/ui/core/photo_picker_service.dart';
import 'package:wenshy_customer/ui/core/push_token_service.dart';
import 'package:wenshy_customer/ui/features/auth/view_models/auth_view_model.dart';
import 'package:wenshy_customer/ui/features/notifications/view_models/notifications_view_model.dart';

/// Shared sample fixtures and fake repositories for unit & widget testing.
abstract final class TestFixtures {
  static final DateTime now = DateTime.utc(2026, 11, 12, 18, 0);

  static User makeUser({String id = 'cust-1', String email = 'sara@wenshy.app'}) {
    return User(
      id: id,
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{'role': 'customer'},
      aud: 'authenticated',
      email: email,
      createdAt: now.toIso8601String(),
    );
  }

  static Session makeSession({String id = 'cust-1'}) {
    return Session(
      accessToken: 'test-access-token',
      tokenType: 'bearer',
      user: makeUser(id: id),
    );
  }

  static UserProfile makeCustomerProfile({
    String id = 'cust-1',
    String fullName = 'سارة أحمد',
    String phone = '+201001112233',
    String locale = 'ar',
  }) {
    return UserProfile.fromJson(<String, dynamic>{
      'id': id,
      'role': 'customer',
      'full_name': fullName,
      'phone': phone,
      'avatar_url': null,
      'locale': locale,
      'is_active': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static WinchType makeFlatbedWinchType() {
    return WinchType.fromJson(<String, dynamic>{
      'id': 'wt-flatbed',
      'code': 'flatbed',
      'name_ar': 'ونش مسطح (فلات بد)',
      'name_en': 'Flatbed Tow Truck',
      'description_ar': 'سحب كامل وآمن للسيارات الحديثة',
      'description_en': 'Full platform carrier for modern cars',
      'base_fare': 250.0,
      'price_per_km': 22.0,
      'minimum_fare': 300.0,
      'min_fare': 300.0,
      'max_weight_kg': 3500,
      'max_vehicle_weight_kg': 3500,
      'icon_name': 'flatbed',
      'sort_order': 1,
      'is_active': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static WinchType makeWheelLiftWinchType() {
    return WinchType.fromJson(<String, dynamic>{
      'id': 'wt-wheel-lift',
      'code': 'wheel_lift',
      'name_ar': 'ونش شوكة',
      'name_en': 'Wheel-Lift Tow Truck',
      'description_ar': 'ونش سريع للمناطق المزدحمة',
      'description_en': 'Quick hook carrier for city streets',
      'base_fare': 180.0,
      'price_per_km': 18.0,
      'minimum_fare': 220.0,
      'min_fare': 220.0,
      'max_weight_kg': 2500,
      'max_vehicle_weight_kg': 2500,
      'icon_name': 'wheel_lift',
      'sort_order': 2,
      'is_active': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static NearbyDriver makeNearbyDriver({
    String driverId = 'drv-1',
    String winchTypeId = 'wt-flatbed',
  }) {
    return NearbyDriver.fromJson(<String, dynamic>{
      'driver_id': driverId,
      'full_name': 'كابتن كريم محمود',
      'phone': '+201112223344',
      'avg_rating': 4.8,
      'total_trips': 42,
      'winch_id': 'winch-1',
      'winch_type_id': winchTypeId,
      'winch_brand': 'إيسوزو',
      'winch_model': 'NPR',
      'plate_number': 'س ط 1234',
      'lat': 30.0480,
      'lng': 31.2400,
      'current_lat': 30.0480,
      'current_lng': 31.2400,
      'distance_meters': 950.0,
      'eta_minutes': 5,
    });
  }

  static WinchQuote makeQuote({
    String winchTypeId = 'wt-flatbed',
    double estimatedPrice = 470.0,
  }) {
    final isWheel = winchTypeId == 'wt-wheel-lift';
    return WinchQuote.fromJson(<String, dynamic>{
      'winch_type_id': winchTypeId,
      'code': isWheel ? 'wheel_lift' : 'flatbed',
      'winch_code': isWheel ? 'wheel_lift' : 'flatbed',
      'winch_type_code': isWheel ? 'wheel_lift' : 'flatbed',
      'winch_name_ar': isWheel ? 'ونش شوكة' : 'ونش مسطح (فلات بد)',
      'winch_name_en': isWheel ? 'Wheel-Lift Tow Truck' : 'Flatbed Tow Truck',
      'name_ar': isWheel ? 'ونش شوكة' : 'ونش مسطح (فلات بد)',
      'name_en': isWheel ? 'Wheel-Lift Tow Truck' : 'Flatbed Tow Truck',
      'geodesic_distance_km': 9.2,
      'estimated_distance_km': 10.0,
      'estimated_duration_min': 22,
      'base_fare': isWheel ? 180.0 : 250.0,
      'price_per_km': isWheel ? 18.0 : 22.0,
      'minimum_fare': isWheel ? 220.0 : 300.0,
      'surge_multiplier': 1.0,
      'estimated_price': estimatedPrice,
      'min_price_range': estimatedPrice - 30,
      'max_price_range': estimatedPrice + 40,
      'currency': 'EGP',
    });
  }

  static CustomerVehicle makeVehicle({
    String id = 'veh-1',
    String customerId = 'cust-1',
    String make = 'تويوتا',
    String model = 'كورولا',
    String plateNumber = 'أ ب ج 456',
    bool isDefault = true,
  }) {
    return CustomerVehicle.fromJson(<String, dynamic>{
      'id': id,
      'customer_id': customerId,
      'make': make,
      'model': model,
      'year': 2022,
      'color': 'فضي',
      'plate_number': plateNumber,
      'vehicle_category': 'sedan',
      'notes': null,
      'is_default': isDefault,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static RescueRequest makeRescueRequest({
    String id = 'req-1',
    String requestCode = 'WNS-1001',
    String status = 'searching',
    String? driverId,
    String? winchId,
    int currentWave = 1,
    double? finalPrice,
    List<String> photoPaths = const <String>[],
  }) {
    return RescueRequest.fromJson(<String, dynamic>{
      'id': id,
      'request_code': requestCode,
      'customer_id': 'cust-1',
      'driver_id': driverId,
      'winch_id': winchId,
      'winch_type_id': 'wt-flatbed',
      'status': status,
      'pickup_lat': 30.0444,
      'pickup_lng': 31.2357,
      'pickup_address': 'ميدان التحرير، القاهرة',
      'dropoff_lat': 30.0626,
      'dropoff_lng': 31.2497,
      'dropoff_address': 'مدينة نصر، القاهرة',
      'customer_vehicle_id': 'veh-1',
      'vehicle_make': 'تويوتا',
      'vehicle_model': 'كورولا',
      'vehicle_year': 2022,
      'vehicle_color': 'فضي',
      'vehicle_plate': 'أ ب ج 456',
      'vehicle_category': 'sedan',
      'breakdown_reason': 'عطل بطارية',
      'breakdown_notes': null,
      'breakdown_photo_paths': photoPaths,
      'geodesic_distance_km': 9.2,
      'route_distance_km': 10.0,
      'estimated_distance_km': 10.0,
      'estimated_duration_min': 22,
      'base_fare_snapshot': 250.0,
      'price_per_km_snapshot': 22.0,
      'minimum_fare_snapshot': 300.0,
      'estimated_price': 470.0,
      'min_price_range': 440.0,
      'max_price_range': 510.0,
      'final_price': finalPrice,
      'currency': 'EGP',
      'payment_method': 'cash',
      'payment_status': 'pending',
      'current_wave': currentWave,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static DispatchResult makeDispatchResult({
    String requestId = 'req-1',
    int wave = 1,
    int dispatchedCount = 3,
  }) {
    return DispatchResult.fromJson(<String, dynamic>{
      'request_id': requestId,
      'wave': wave,
      'dispatched_count': dispatchedCount,
      'offer_ids': List<String>.generate(dispatchedCount, (i) => 'offer-$i'),
    });
  }

  static DriverProfile makeDriverProfile({String id = 'drv-1'}) {
    return DriverProfile.fromJson(<String, dynamic>{
      'id': id,
      'license_number': 'LIC-9988',
      'national_id': '29001011234567',
      'approval_status': 'approved',
      'is_online': true,
      'is_verified': true,
      'avg_rating': 4.9,
      'total_trips': 85,
      'total_ratings': 72,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'profiles': <String, dynamic>{
        'id': id,
        'role': 'driver',
        'full_name': 'كابتن كريم محمود',
        'phone': '+201112223344',
        'locale': 'ar',
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    });
  }

  static DriverWinch makeDriverWinch({String id = 'winch-1'}) {
    return DriverWinch.fromJson(<String, dynamic>{
      'id': id,
      'driver_id': 'drv-1',
      'winch_type_id': 'wt-flatbed',
      'brand': 'إيسوزو',
      'make': 'إيسوزو',
      'model': 'NPR',
      'year': 2023,
      'color': 'أصفر',
      'plate_number': 'س ط 1234',
      'is_primary': true,
      'is_active': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static TripStatusLog makeStatusLog({
    int id = 1,
    String? fromStatus,
    String toStatus = 'driver_assigned',
  }) {
    return TripStatusLog.fromJson(<String, dynamic>{
      'id': id,
      'request_id': 'req-1',
      'from_status': fromStatus,
      'to_status': toStatus,
      'changed_by': 'drv-1',
      'created_at': now.toIso8601String(),
    });
  }

  static TripLocationPoint makeLocationPoint({
    double lat = 30.0500,
    double lng = 31.2410,
    double heading = 90.0,
  }) {
    return TripLocationPoint.fromJson(<String, dynamic>{
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed_kmh': 45.0,
      'recorded_at': now.toIso8601String(),
    });
  }

  static TripRating makeRating({
    String requestId = 'req-1',
    int score = 5,
    String? comment = 'خدمة ممتازة',
  }) {
    return TripRating.fromJson(<String, dynamic>{
      'id': 'rat-1',
      'request_id': requestId,
      'customer_id': 'cust-1',
      'driver_id': 'drv-1',
      'score': score,
      'comment': comment,
      'tags': const <String>['سرعة الوصول'],
      'created_at': now.toIso8601String(),
    });
  }

  static Complaint makeComplaint({
    String id = 'cmp-1',
    String code = 'CMP-201',
    String subject = 'تأخر في الوصول',
    String description = 'تأخر السائق 20 دقيقة',
    String status = 'open',
  }) {
    return Complaint.fromJson(<String, dynamic>{
      'id': id,
      'complaint_code': code,
      'request_id': 'req-1',
      'reporter_id': 'cust-1',
      'reported_user_id': 'drv-1',
      'category': 'delay',
      'subject': subject,
      'description': description,
      'evidence_paths': const <String>[],
      'status': status,
      'admin_notes': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  static SelectedPhotoBytes makeSamplePhoto({String name = 'damage.jpg'}) {
    return SelectedPhotoBytes(
      fileName: name,
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    );
  }

  static AppNotification makeNotification({
    String id = 'notif-1',
    String userId = 'cust-1',
    String titleAr = 'تم تعيين سائق للرحلة',
    String titleEn = 'Driver Assigned',
    String bodyAr = 'كابتن كريم في طريقه إليك الآن.',
    String bodyEn = 'Captain Kareem is on the way.',
    String type = 'trip_driver_assigned',
    bool isRead = false,
    Map<String, dynamic> data = const <String, dynamic>{'request_id': 'req-1'},
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      titleAr: titleAr,
      titleEn: titleEn,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
      type: type,
      data: data,
      isRead: isRead,
      createdAt: now,
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    bool initiallySignedIn = true,
    UserProfile? initialProfile,
  })  : _session = initiallySignedIn ? TestFixtures.makeSession() : null,
        _profile = initiallySignedIn
            ? (initialProfile ?? TestFixtures.makeCustomerProfile())
            : null;

  Session? _session;
  UserProfile? _profile;
  final _controller = StreamController<AuthState>.broadcast();
  int signInCalls = 0;
  int signUpCalls = 0;
  String? lastPasswordResetEmail;
  String? lastOtpPhone;
  String? lastVerifiedOtpToken;
  String? lastDeleteAccountReason;
  int deleteAccountCalls = 0;
  Object? deleteAccountError;
  Object? otpVerifyError;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  String? get currentUserId => _session?.user.id;

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    _session = TestFixtures.makeSession();
    _profile ??= TestFixtures.makeCustomerProfile();
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
    return AuthResponse(session: _session, user: _session!.user);
  }

  @override
  Future<AuthResponse> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String locale = 'ar',
  }) async {
    signUpCalls++;
    _session = TestFixtures.makeSession();
    _profile = TestFixtures.makeCustomerProfile(
      fullName: fullName,
      phone: phone ?? '+201000000000',
      locale: locale,
    );
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
    return AuthResponse(session: _session, user: _session!.user);
  }

  @override
  Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    lastPasswordResetEmail = email.trim();
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    lastOtpPhone = phone.trim();
  }

  @override
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    if (otpVerifyError != null) {
      throw otpVerifyError!;
    }
    lastOtpPhone = phone.trim();
    lastVerifiedOtpToken = token.trim();
    _session = TestFixtures.makeSession();
    _profile ??= TestFixtures.makeCustomerProfile(phone: phone.trim());
    _controller.add(AuthState(AuthChangeEvent.signedIn, _session));
    return AuthResponse(session: _session, user: _session!.user);
  }

  @override
  Future<void> deleteMyAccount({String? reason}) async {
    if (deleteAccountError != null) {
      throw deleteAccountError!;
    }
    deleteAccountCalls++;
    lastDeleteAccountReason = reason;
    await signOut();
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _profile = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<UserProfile?> getCurrentProfile() async => _profile;

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? fcmToken,
    String? locale,
  }) async {
    final current = _profile ?? TestFixtures.makeCustomerProfile();
    _profile = UserProfile.fromJson(<String, dynamic>{
      ...current.toJson(),
      'full_name': ?fullName,
      'phone': ?phone,
      'avatar_url': ?avatarUrl,
      'locale': ?locale,
    });
    return _profile!;
  }

  Future<void> dispose() => _controller.close();
}

class FakeMapAndQuoteRepository implements MapAndQuoteRepository {
  LatLng? gpsLocation = const LatLng(30.0550, 31.2450);
  List<WinchType> winchTypes = <WinchType>[
    TestFixtures.makeFlatbedWinchType(),
    TestFixtures.makeWheelLiftWinchType(),
  ];
  List<NearbyDriver> nearbyDrivers = <NearbyDriver>[
    TestFixtures.makeNearbyDriver(),
  ];

  final List<String> quoteWinchTypeIds = <String>[];
  double? lastQuoteRouteDistanceKm;
  String? lastSearchQuery;
  int reverseGeocodeCalls = 0;
  int drivingRouteCalls = 0;

  List<GeoPlaceSuggestion> placeSuggestions = const <GeoPlaceSuggestion>[
    GeoPlaceSuggestion(
      displayName: 'ميدان التحرير، وسط البلد، القاهرة، مصر',
      shortName: 'ميدان التحرير، القاهرة',
      lat: 30.0444,
      lng: 31.2357,
    ),
    GeoPlaceSuggestion(
      displayName: 'شارع عباس العقاد، مدينة نصر، القاهرة، مصر',
      shortName: 'عباس العقاد، مدينة نصر',
      lat: 30.0626,
      lng: 31.3375,
    ),
  ];

  String? reverseGeocodeLabel = 'شارع التحرير، الدقي، الجيزة';

  RoadRouteResult? drivingRouteResult;

  @override
  Future<LatLng?> getCurrentLocation() async => gpsLocation;

  @override
  Future<List<WinchType>> getActiveWinchTypes() async => winchTypes;

  @override
  Future<List<NearbyDriver>> findNearestDrivers({
    required double pickupLat,
    required double pickupLng,
    required String winchTypeId,
    int radiusMeters = 15000,
    int limit = 10,
  }) async {
    return List<NearbyDriver>.unmodifiable(nearbyDrivers);
  }

  @override
  Future<WinchQuote> calculateQuote({
    required String winchTypeId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? routeDistanceKm,
  }) async {
    quoteWinchTypeIds.add(winchTypeId);
    lastQuoteRouteDistanceKm = routeDistanceKm;
    final price = winchTypeId == 'wt-wheel-lift' ? 360.0 : 470.0;
    return TestFixtures.makeQuote(
      winchTypeId: winchTypeId,
      estimatedPrice: price,
    );
  }

  @override
  Future<List<GeoPlaceSuggestion>> searchPlaces(
    String query, {
    String locale = 'ar',
    String countryCode = 'eg',
    int limit = 5,
  }) async {
    lastSearchQuery = query;
    return placeSuggestions.take(limit).toList(growable: false);
  }

  @override
  Future<String?> reverseGeocode(
    double lat,
    double lng, {
    String locale = 'ar',
  }) async {
    reverseGeocodeCalls++;
    return reverseGeocodeLabel;
  }

  @override
  Future<RoadRouteResult> getDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    drivingRouteCalls++;
    if (drivingRouteResult != null) return drivingRouteResult!;
    final midLat = (fromLat + toLat) / 2;
    final midLng = (fromLng + toLng) / 2 + 0.005;
    return RoadRouteResult(
      points: <({double lat, double lng})>[
        (lat: fromLat, lng: fromLng),
        (lat: midLat, lng: midLng),
        (lat: toLat, lng: toLng),
      ],
      distanceKm: 12.4,
      durationMinutes: 24,
      isFallback: false,
    );
  }
}

class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository({List<CustomerVehicle>? initial})
      : vehicles = List<CustomerVehicle>.from(
          initial ?? <CustomerVehicle>[TestFixtures.makeVehicle()],
        );

  final List<CustomerVehicle> vehicles;
  int _nextId = 2;

  @override
  Future<List<CustomerVehicle>> fetchVehicles(String customerId) async {
    return List<CustomerVehicle>.unmodifiable(vehicles);
  }

  @override
  Future<CustomerVehicle> createVehicle({
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      for (var i = 0; i < vehicles.length; i++) {
        vehicles[i] = CustomerVehicle.fromJson(<String, dynamic>{
          ...vehicles[i].toJson(),
          'is_default': false,
        });
      }
    }
    final created = CustomerVehicle.fromJson(<String, dynamic>{
      'id': 'veh-${_nextId++}',
      'customer_id': customerId,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plate_number': plateNumber,
      'vehicle_category': category.toJson(),
      'notes': notes,
      'is_default': isDefault,
      'created_at': TestFixtures.now.toIso8601String(),
      'updated_at': TestFixtures.now.toIso8601String(),
    });
    vehicles.insert(0, created);
    return created;
  }

  @override
  Future<CustomerVehicle> updateVehicle({
    required String vehicleId,
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      for (var i = 0; i < vehicles.length; i++) {
        vehicles[i] = CustomerVehicle.fromJson(<String, dynamic>{
          ...vehicles[i].toJson(),
          'is_default': vehicles[i].id == vehicleId,
        });
      }
    }
    final idx = vehicles.indexWhere((v) => v.id == vehicleId);
    final updated = CustomerVehicle.fromJson(<String, dynamic>{
      ...vehicles[idx].toJson(),
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'plate_number': plateNumber,
      'vehicle_category': category.toJson(),
      'notes': notes,
      'is_default': isDefault,
    });
    vehicles[idx] = updated;
    return updated;
  }

  @override
  Future<void> setDefaultVehicle({
    required String customerId,
    required String vehicleId,
  }) async {
    for (var i = 0; i < vehicles.length; i++) {
      vehicles[i] = CustomerVehicle.fromJson(<String, dynamic>{
        ...vehicles[i].toJson(),
        'is_default': vehicles[i].id == vehicleId,
      });
    }
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    vehicles.removeWhere((v) => v.id == vehicleId);
  }
}

class FakeTripSubscription implements TripRealtimeSubscription {
  FakeTripSubscription({
    required this.onTripUpdate,
    required this.onDriverLocation,
    this.onStatus,
  });

  final void Function(RescueRequest? updated, Map<String, dynamic> raw)
      onTripUpdate;
  final void Function(TripLocationPoint location) onDriverLocation;
  final void Function(RealtimeSubscribeStatus status, Object? error)? onStatus;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeRescueRequestRepository implements RescueRequestRepository {
  final List<String> callLog = <String>[];
  final Map<String, RescueRequest> requestsById = <String, RescueRequest>{
    'req-1': TestFixtures.makeRescueRequest(),
  };
  List<TripStatusLog> statusLogs = <TripStatusLog>[
    TestFixtures.makeStatusLog(),
  ];
  DriverProfile? driverProfile = TestFixtures.makeDriverProfile();
  DriverWinch? driverWinch = TestFixtures.makeDriverWinch();
  TripLocationPoint? latestLocation;
  DispatchResult? nextWaveResult;
  FakeTripSubscription? activeSubscription;
  int lastRequestedWave = 1;
  bool cancelSuccess = true;
  double? lastCreatedRouteDistanceKm;

  @override
  Future<CreateRescueRequestResult> createRescueRequest({
    required String winchTypeId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    String? customerVehicleId,
    String? vehicleMake,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? vehiclePlate,
    VehicleCategory vehicleCategory = VehicleCategory.sedan,
    String? breakdownReason,
    String? breakdownNotes,
    List<String> breakdownPhotoPaths = const <String>[],
    PaymentMethod paymentMethod = PaymentMethod.cash,
    double? routeDistanceKm,
    int initialRadiusMeters = 15000,
  }) async {
    callLog.add('createRescueRequest');
    lastCreatedRouteDistanceKm = routeDistanceKm;
    final created = TestFixtures.makeRescueRequest();
    requestsById[created.id] = created;
    return CreateRescueRequestResult(
      request: created,
      quote: TestFixtures.makeQuote(winchTypeId: winchTypeId),
      dispatch: TestFixtures.makeDispatchResult(requestId: created.id),
    );
  }

  @override
  Future<List<String>> uploadAndAttachBreakdownPhotos({
    required String customerId,
    required String requestId,
    required List<SelectedPhotoBytes> photos,
  }) async {
    callLog.add('uploadAndAttachBreakdownPhotos:$requestId');
    return photos
        .map((p) => '$customerId/$requestId/${p.fileName}')
        .toList(growable: false);
  }

  @override
  Future<RescueRequest?> getRescueRequestById(String requestId) async {
    return requestsById[requestId];
  }

  @override
  Future<List<RescueRequest>> getCustomerTrips(String customerId) async {
    return requestsById.values.toList(growable: false);
  }

  @override
  Future<RescueRequest?> getLatestActiveTrip(String customerId) async {
    for (final req in requestsById.values) {
      if (!req.status.isTerminal) return req;
    }
    return null;
  }

  @override
  Future<DriverProfile?> getAssignedDriverInfo(String driverId) async =>
      driverProfile;

  @override
  Future<DriverWinch?> getAssignedWinchInfo(String winchId) async =>
      driverWinch;

  @override
  Future<List<TripStatusLog>> getTripStatusLogs(String requestId) async =>
      statusLogs;

  @override
  Future<TripLocationPoint?> getLatestDriverLocation(String requestId) async =>
      latestLocation;

  @override
  Future<DispatchResult> dispatchNextWave({
    required String requestId,
    int radiusMeters = 25000,
    int waveNumber = 2,
    int batchSize = 5,
    int offerTtlSeconds = 45,
  }) async {
    lastRequestedWave = waveNumber;
    final current = requestsById[requestId];
    if (current != null) {
      requestsById[requestId] =
          current.copyWith(currentWave: waveNumber);
    }
    return nextWaveResult ??
        TestFixtures.makeDispatchResult(
          requestId: requestId,
          wave: waveNumber,
          dispatchedCount: 2,
        );
  }

  @override
  Future<bool> cancelRescueRequest({
    required String requestId,
    String? reason,
  }) async {
    callLog.add('cancelRescueRequest:$requestId');
    final current = requestsById[requestId];
    if (current != null && cancelSuccess) {
      requestsById[requestId] = RescueRequest.fromJson(<String, dynamic>{
        ...current.toJson(),
        'status': 'cancelled',
        'cancellation_reason': reason,
      });
    }
    return cancelSuccess;
  }

  @override
  Future<Map<String, String>> getBreakdownPhotoSignedUrls(
    List<String> paths,
  ) async {
    return <String, String>{for (final p in paths) p: 'https://example.com/$p'};
  }

  @override
  TripRealtimeSubscription subscribeToTrip({
    required String requestId,
    required void Function(RescueRequest? updated, Map<String, dynamic> raw)
        onTripUpdate,
    required void Function(TripLocationPoint location) onDriverLocation,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    final sub = FakeTripSubscription(
      onTripUpdate: onTripUpdate,
      onDriverLocation: onDriverLocation,
      onStatus: onStatus,
    );
    activeSubscription = sub;
    onStatus?.call(RealtimeSubscribeStatus.subscribed, null);
    return sub;
  }
}

class FakeFeedbackRepository implements FeedbackRepository {
  TripRating? storedRating;
  final List<Complaint> complaints = <Complaint>[
    TestFixtures.makeComplaint(),
  ];

  @override
  Future<TripRating?> getRatingForRequest(String requestId) async {
    if (storedRating?.requestId == requestId) return storedRating;
    return null;
  }

  @override
  Future<TripRating> submitRating({
    required String requestId,
    required String customerId,
    required String driverId,
    required int score,
    String? comment,
    List<String> tags = const <String>[],
  }) async {
    final created = TripRating.fromJson(<String, dynamic>{
      'id': 'rat-new',
      'request_id': requestId,
      'customer_id': customerId,
      'driver_id': driverId,
      'score': score,
      'comment': comment,
      'tags': tags,
      'created_at': TestFixtures.now.toIso8601String(),
    });
    storedRating = created;
    return created;
  }

  @override
  Future<List<Complaint>> getMyComplaints(String reporterId) async {
    return List<Complaint>.unmodifiable(complaints);
  }

  @override
  Future<Complaint> submitComplaint({
    required String reporterId,
    String? requestId,
    String? reportedUserId,
    required ComplaintCategory category,
    required String subject,
    required String description,
    List<SelectedPhotoBytes> evidenceFiles = const <SelectedPhotoBytes>[],
  }) async {
    final created = Complaint.fromJson(<String, dynamic>{
      'id': 'cmp-new',
      'complaint_code': 'CMP-999',
      'request_id': requestId,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'category': category.toJson(),
      'subject': subject,
      'description': description,
      'evidence_paths':
          evidenceFiles.map((e) => '$reporterId/${e.fileName}').toList(),
      'status': 'open',
      'admin_notes': null,
      'created_at': TestFixtures.now.toIso8601String(),
      'updated_at': TestFixtures.now.toIso8601String(),
    });
    complaints.insert(0, created);
    return created;
  }

  @override
  Future<Map<String, String>> getComplaintEvidenceSignedUrls(
    List<String> paths,
  ) async {
    return <String, String>{for (final p in paths) p: 'https://example.com/$p'};
  }
}

class FakePhotoPickerService implements PhotoPickerService {
  SelectedPhotoBytes? cameraPhoto;
  List<SelectedPhotoBytes> galleryPhotos = <SelectedPhotoBytes>[];

  @override
  Future<SelectedPhotoBytes?> pickFromCamera() async => cameraPhoto;

  @override
  Future<SelectedPhotoBytes?> pickSingleFromGallery() async =>
      galleryPhotos.isEmpty ? null : galleryPhotos.first;

  @override
  Future<List<SelectedPhotoBytes>> pickMultipleFromGallery({
    int limit = 4,
  }) async =>
      galleryPhotos.take(limit).toList(growable: false);
}

class FakeWinchCatalogService extends WinchCatalogService {
  const FakeWinchCatalogService();

  @override
  Future<List<WinchType>> getActiveWinchTypes() async {
    return <WinchType>[
      TestFixtures.makeFlatbedWinchType(),
      TestFixtures.makeWheelLiftWinchType(),
    ];
  }

  @override
  Future<WinchType?> getWinchTypeById(String id) async {
    if (id == 'wt-wheel-lift') return TestFixtures.makeWheelLiftWinchType();
    return TestFixtures.makeFlatbedWinchType();
  }
}

class FakeNotificationSubscription implements NotificationRealtimeSubscription {
  FakeNotificationSubscription({
    required this.onInsert,
    required this.onUpdate,
  });

  final void Function(AppNotification notification) onInsert;
  final void Function(AppNotification notification) onUpdate;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? initial})
      : notifications = List<AppNotification>.from(
          initial ??
              <AppNotification>[
                TestFixtures.makeNotification(),
                TestFixtures.makeNotification(
                  id: 'notif-2',
                  titleAr: 'اكتملت الرحلة',
                  titleEn: 'Trip Completed',
                  bodyAr: 'تم تسليم سيارتك بأمان.',
                  bodyEn: 'Your vehicle has been delivered safely.',
                  type: 'trip_delivered',
                  isRead: true,
                ),
              ],
        );

  final List<AppNotification> notifications;
  final List<({String userId, String token, String platform})> upsertedTokens =
      <({String userId, String token, String platform})>[];
  final List<String> deactivatedTokens = <String>[];
  FakeNotificationSubscription? activeSubscription;

  @override
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  }) async {
    return List<AppNotification>.unmodifiable(notifications.take(limit));
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final idx = notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      notifications[idx] = notifications[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    upsertedTokens.add((userId: userId, token: token, platform: platform));
  }

  @override
  Future<void> deactivateDeviceToken(String token) async {
    deactivatedTokens.add(token);
  }

  @override
  NotificationRealtimeSubscription subscribeToNotifications({
    required String userId,
    required void Function(AppNotification notification) onInsert,
    required void Function(AppNotification notification) onUpdate,
  }) {
    final sub = FakeNotificationSubscription(
      onInsert: onInsert,
      onUpdate: onUpdate,
    );
    activeSubscription = sub;
    return sub;
  }
}

class FakePushTokenProvider implements PushTokenProvider {
  FakePushTokenProvider({this.token = 'fcm-test-token-123', this.platform = 'android'});

  String? token;
  @override
  final String platform;
  final _refreshController = StreamController<String>.broadcast();

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refreshController.stream;

  void emitRefresh(String newToken) => _refreshController.add(newToken);

  Future<void> dispose() => _refreshController.close();
}

class FakePhoneDialer implements PhoneDialer {
  final List<String> calledNumbers = <String>[];
  bool shouldSucceed = true;

  @override
  Future<bool> callPhone(String phoneNumber) async {
    calledNumbers.add(phoneNumber);
    return shouldSucceed;
  }
}

class TestDependencyBundle {
  TestDependencyBundle({
    bool initiallySignedIn = true,
  }) {
    localeController = LocaleController();
    notificationRepository = FakeNotificationRepository();
    pushTokenProvider = FakePushTokenProvider();
    pushTokenRegistrar = PushTokenRegistrar(
      notificationRepository: notificationRepository,
      tokenProvider: pushTokenProvider,
    );
    notificationsViewModel = NotificationsViewModel(
      repository: notificationRepository,
    );
    authRepository = FakeAuthRepository(initiallySignedIn: initiallySignedIn);
    authViewModel = AuthViewModel(
      repository: authRepository,
      localeController: localeController,
      pushTokenRegistrar: pushTokenRegistrar,
      autoListen: true,
    );
    mapRepository = FakeMapAndQuoteRepository();
    vehicleRepository = FakeVehicleRepository();
    rescueRepository = FakeRescueRequestRepository();
    feedbackRepository = FakeFeedbackRepository();
    phoneDialer = FakePhoneDialer();
    photoPicker = FakePhotoPickerService();
    dependencies = AppDependencies(
      localeController: localeController,
      authRepository: authRepository,
      authViewModel: authViewModel,
      mapRepository: mapRepository,
      vehicleRepository: vehicleRepository,
      rescueRepository: rescueRepository,
      feedbackRepository: feedbackRepository,
      notificationRepository: notificationRepository,
      notificationsViewModel: notificationsViewModel,
      pushTokenRegistrar: pushTokenRegistrar,
      phoneDialer: phoneDialer,
      photoPicker: photoPicker,
      winchCatalog: const FakeWinchCatalogService(),
      enableNetworkTiles: false,
    );
  }

  late final LocaleController localeController;
  late final FakeAuthRepository authRepository;
  late final AuthViewModel authViewModel;
  late final FakeMapAndQuoteRepository mapRepository;
  late final FakeVehicleRepository vehicleRepository;
  late final FakeRescueRequestRepository rescueRepository;
  late final FakeFeedbackRepository feedbackRepository;
  late final FakeNotificationRepository notificationRepository;
  late final NotificationsViewModel notificationsViewModel;
  late final FakePushTokenProvider pushTokenProvider;
  late final PushTokenRegistrar pushTokenRegistrar;
  late final FakePhoneDialer phoneDialer;
  late final FakePhotoPickerService photoPicker;
  late final AppDependencies dependencies;

  Future<void> dispose() async {
    dependencies.dispose();
    await pushTokenProvider.dispose();
    await authRepository.dispose();
  }
}
