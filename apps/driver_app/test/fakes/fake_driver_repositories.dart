import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/data/repositories/driver_auth_repository.dart';
import 'package:wenshy_driver/data/repositories/driver_dispatch_repository.dart';
import 'package:wenshy_driver/data/repositories/driver_history_repository.dart';
import 'package:wenshy_driver/data/repositories/driver_notification_repository.dart';
import 'package:wenshy_driver/data/repositories/driver_onboarding_repository.dart';
import 'package:wenshy_driver/data/repositories/driver_trip_repository.dart';
import 'package:wenshy_driver/data/services/external_launcher_service.dart';
import 'package:wenshy_driver/data/services/location_service.dart';
import 'package:wenshy_driver/data/services/media_picker_service.dart';
import 'package:wenshy_driver/data/services/push_token_service.dart';
import 'package:wenshy_driver/ui/core/app_router.dart';
import 'package:wenshy_driver/ui/core/driver_session_controller.dart';
import 'package:wenshy_driver/ui/core/locale_controller.dart';
import 'package:wenshy_driver/ui/features/notifications/view_models/notifications_view_model.dart';

class TestFixtures {
  static final DateTime baseTime = DateTime.utc(2026, 11, 12, 18, 0, 0);

  static UserProfile driverUserProfile({
    String id = 'driver-1',
    AppRole role = AppRole.driver,
    String fullName = 'محمود أحمد',
    String locale = 'ar',
    bool isActive = true,
  }) =>
      UserProfile(
        id: id,
        role: role,
        fullName: fullName,
        phone: '+201001234567',
        email: 'driver@wenshy.test',
        isActive: isActive,
        locale: locale,
        createdAt: baseTime,
        updatedAt: baseTime,
      );

  static DriverProfile driverProfile({
    String id = 'driver-1',
    DriverApprovalStatus approvalStatus = DriverApprovalStatus.approved,
    String? rejectionReason,
    bool isOnline = false,
    bool isAvailable = true,
    int totalTrips = 12,
    double totalEarnings = 6850.0,
    double avgRating = 4.92,
    int totalRatings = 10,
  }) =>
      DriverProfile(
        id: id,
        nationalIdNumber: '29001011234567',
        licenseNumber: 'DL-998877',
        approvalStatus: approvalStatus,
        rejectionReason: rejectionReason,
        isOnline: isOnline,
        isAvailable: isAvailable,
        currentLat: 30.0444,
        currentLng: 31.2357,
        avgRating: avgRating,
        totalRatings: totalRatings,
        totalTrips: totalTrips,
        totalEarnings: totalEarnings,
        createdAt: baseTime,
        updatedAt: baseTime,
        profile: driverUserProfile(id: id),
      );

  static WinchType winchType({String id = 'wt-flatbed'}) => WinchType(
        id: id,
        code: 'flatbed',
        nameAr: 'ونش سطحة',
        nameEn: 'Flatbed Tow Truck',
        baseFare: 300,
        pricePerKm: 22,
        minimumFare: 450,
        createdAt: baseTime,
        updatedAt: baseTime,
      );

  static RescueRequest rescueRequest({
    String id = 'req-1',
    String driverId = 'driver-1',
    TripStatus status = TripStatus.driverAssigned,
  }) =>
      RescueRequest(
        id: id,
        requestCode: 'WN-100001',
        customerId: 'cust-1',
        driverId: driverId,
        winchTypeId: 'wt-flatbed',
        winchId: 'winch-1',
        vehicleMake: 'Toyota',
        vehicleModel: 'Corolla',
        vehicleYear: 2022,
        vehiclePlate: 'أ ب ج 123',
        breakdownReason: 'عطل محرك مفاجئ',
        pickupLat: 30.05,
        pickupLng: 31.24,
        pickupAddress: 'كوبري 6 أكتوبر، القاهرة',
        dropoffLat: 30.09,
        dropoffLng: 31.33,
        dropoffAddress: 'مدينة نصر، القاهرة',
        geodesicDistanceKm: 10.5,
        estimatedDistanceKm: 13.0,
        estimatedDurationMin: 24,
        baseFareSnapshot: 300,
        pricePerKmSnapshot: 22,
        estimatedPrice: 586,
        status: status,
        createdAt: baseTime,
        updatedAt: baseTime,
      );

  static DispatchOffer dispatchOffer({
    String id = 'offer-1',
    String requestId = 'req-1',
    String driverId = 'driver-1',
    OfferStatus status = OfferStatus.pending,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    final created = createdAt ?? baseTime;
    return DispatchOffer(
      id: id,
      requestId: requestId,
      driverId: driverId,
      winchId: 'winch-1',
      distanceMeters: 2400,
      etaMinutes: 6,
      waveNumber: 1,
      status: status,
      expiresAt: expiresAt ?? created.add(const Duration(seconds: 45)),
      createdAt: created,
      updatedAt: created,
      rescueRequest: rescueRequest(id: requestId, status: TripStatus.searching),
    );
  }
}

class FakeDriverAuthRepository implements DriverAuthRepository {
  FakeDriverAuthRepository({
    this.userId,
    this.userProfile,
    this.driverProfile,
  });

  String? userId;
  UserProfile? userProfile;
  DriverProfile? driverProfile;
  Map<String, dynamic>? lastSignUpArgs;
  String? updatedLocale;
  Object? signInError;
  Object? passwordResetError;
  Object? otpError;
  Object? deleteAccountError;
  String? lastPasswordResetEmail;
  String? lastOtpPhone;
  String? lastVerifiedOtpPhone;
  String? lastVerifiedOtpToken;
  String? lastDeleteReason;
  bool deleteAccountCalled = false;

  final StreamController<AuthState> _authController =
      StreamController<AuthState>.broadcast();

  @override
  String? get currentUserId => userId;

  @override
  Stream<AuthState> get onAuthStateChange => _authController.stream;

  @override
  Future<UserProfile?> getCurrentProfile() async => userProfile;

  @override
  Future<DriverProfile?> getDriverProfile() async => driverProfile;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    if (userProfile != null && userProfile!.role != AppRole.driver) {
      userId = null;
      throw const DriverAuthFailure(
        'invalid_role',
        'Restricted to drivers only.',
      );
    }
    userId ??= userProfile?.id ?? 'driver-1';
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
    lastSignUpArgs = <String, dynamic>{
      'role': 'driver',
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'national_id_number': nationalIdNumber,
      'license_number': licenseNumber,
      'locale': locale,
    };
    userId = 'driver-new';
    userProfile = TestFixtures.driverUserProfile(
      id: 'driver-new',
      fullName: fullName,
      locale: locale,
    );
    driverProfile = TestFixtures.driverProfile(
      id: 'driver-new',
      approvalStatus: DriverApprovalStatus.pending,
    );
    return const DriverSignUpResult(
      requiresEmailVerification: false,
      userId: 'driver-new',
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (passwordResetError != null) throw passwordResetError!;
    lastPasswordResetEmail = email;
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    if (otpError != null) throw otpError!;
    lastOtpPhone = phone;
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    if (otpError != null) throw otpError!;
    lastVerifiedOtpPhone = phone;
    lastVerifiedOtpToken = token;
    if (userProfile != null && userProfile!.role != AppRole.driver) {
      userId = null;
      throw const DriverAuthFailure(
        'invalid_role',
        'Restricted to drivers only.',
      );
    }
    userId ??= userProfile?.id ?? 'driver-1';
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final base = userProfile ?? TestFixtures.driverUserProfile();
    userProfile = base.copyWith(
      fullName: fullName ?? base.fullName,
      phone: phone ?? base.phone,
    );
    if (driverProfile != null) {
      driverProfile = driverProfile!.copyWith(profile: userProfile);
    }
    return userProfile!;
  }

  @override
  Future<UserProfile> updateLocale(String locale) async {
    updatedLocale = locale;
    userProfile = (userProfile ?? TestFixtures.driverUserProfile())
        .copyWith(locale: locale);
    return userProfile!;
  }

  @override
  Future<void> deleteMyAccount({String? reason}) async {
    if (deleteAccountError != null) throw deleteAccountError!;
    deleteAccountCalled = true;
    lastDeleteReason = reason;
    userId = null;
    userProfile = null;
    driverProfile = null;
  }

  @override
  Future<void> signOut() async {
    userId = null;
  }

  Future<void> dispose() => _authController.close();
}

class FakeDriverOnboardingRepository implements DriverOnboardingRepository {
  List<WinchType> winchTypes = <WinchType>[TestFixtures.winchType()];
  List<DriverWinch> winches = <DriverWinch>[];
  List<DriverDocument> documents = <DriverDocument>[];

  int upsertCalls = 0;

  @override
  Future<List<WinchType>> getWinchTypes() async => winchTypes;

  @override
  Future<List<DriverWinch>> getMyWinches(String driverId) async => winches;

  @override
  Future<DriverWinch> registerWinch({
    required String driverId,
    required String winchTypeId,
    required String plateNumber,
    required String brand,
    required String model,
    int? year,
    String? color,
    double? maxCapacityTons,
    String? winchLicenseNumber,
    DateTime? winchLicenseExpiry,
    List<PickedMediaFile> photos = const <PickedMediaFile>[],
  }) async {
    final created = DriverWinch(
      id: 'winch-${winches.length + 1}',
      driverId: driverId,
      winchTypeId: winchTypeId,
      plateNumber: plateNumber,
      brand: brand,
      model: model,
      year: year,
      color: color,
      maxCapacityTons: maxCapacityTons,
      winchLicenseNumber: winchLicenseNumber,
      winchLicenseExpiry: winchLicenseExpiry,
      photoPaths: photos
          .map((p) => '$driverId/${p.fileName}')
          .toList(growable: false),
      createdAt: TestFixtures.baseTime,
      updatedAt: TestFixtures.baseTime,
    );
    winches = <DriverWinch>[created, ...winches];
    return created;
  }

  @override
  Future<DriverWinch> addWinchPhotos({
    required String driverId,
    required DriverWinch winch,
    required List<PickedMediaFile> newPhotos,
  }) async =>
      winch;

  @override
  Future<List<DriverDocument>> getMyDocuments(String driverId) async =>
      documents;

  @override
  Future<DriverDocument> uploadKycDocument({
    required String driverId,
    required DocumentType documentType,
    required PickedMediaFile file,
    String? winchId,
    DateTime? expiresAt,
  }) async {
    upsertCalls++;
    final doc = DriverDocument(
      id: 'doc-${documentType.value}',
      driverId: driverId,
      winchId: winchId,
      documentType: documentType,
      storagePath: '$driverId/${documentType.value}/${file.fileName}',
      reviewStatus: DocumentReviewStatus.pending,
      rejectionReason: null,
      expiresAt: expiresAt,
      createdAt: TestFixtures.baseTime,
      updatedAt: TestFixtures.baseTime,
    );
    documents = List<DriverDocument>.from(documents)
      ..removeWhere((d) => d.documentType == documentType)
      ..add(doc);
    return doc;
  }

  @override
  Future<String> getDocumentSignedUrl(String storagePath) async =>
      'https://signed.example/$storagePath';

  @override
  String getWinchPhotoPublicUrl(String storagePath) =>
      'https://public.example/$storagePath';
}

class FakeDriverDispatchRepository implements DriverDispatchRepository {
  final StreamController<DispatchOfferEvent> offersController =
      StreamController<DispatchOfferEvent>.broadcast();

  final List<Map<String, dynamic>> locationSyncCalls = <Map<String, dynamic>>[];
  bool joinedPresence = false;
  bool leftPresence = false;
  List<DispatchOffer> pendingOffers = <DispatchOffer>[];
  AcceptOfferResult nextAcceptResult = const AcceptOfferResult(
    accepted: true,
    requestId: 'req-1',
    requestCode: 'WN-100001',
    status: TripStatus.driverAssigned,
  );
  String? lastAcceptedOfferId;
  String? lastRejectedOfferId;

  @override
  Future<void> syncLocationAndOnlineStatus({
    required double lat,
    required double lng,
    double? heading,
    double? speedKmh,
    bool? isOnline,
    String? activeRequestId,
  }) async {
    locationSyncCalls.add(<String, dynamic>{
      'p_lat': lat,
      'p_lng': lng,
      'p_is_online': isOnline,
      'p_active_request_id': activeRequestId,
    });
  }

  @override
  Future<void> joinOnlinePresence({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    joinedPresence = true;
  }

  @override
  Future<void> leaveOnlinePresence() async {
    leftPresence = true;
  }

  @override
  Future<List<DispatchOffer>> getPendingOffers(String driverId) async =>
      pendingOffers;

  @override
  Future<DispatchOffer?> getOfferById(String offerId) async {
    for (final offer in pendingOffers) {
      if (offer.id == offerId) return offer;
    }
    return null;
  }

  @override
  Stream<DispatchOfferEvent> watchDriverOffers(String driverId) =>
      offersController.stream;

  @override
  Future<AcceptOfferResult> acceptOffer(String offerId) async {
    lastAcceptedOfferId = offerId;
    return nextAcceptResult;
  }

  @override
  Future<bool> rejectOffer(String offerId, {String? reason}) async {
    lastRejectedOfferId = offerId;
    return true;
  }

  @override
  Future<void> disposeSubscriptions() async {}
}

class FakeDriverTripRepository implements DriverTripRepository {
  RescueRequest? activeTrip;
  UserProfile? customerProfile = UserProfile(
    id: 'cust-1',
    role: AppRole.customer,
    fullName: 'سارة محمد',
    phone: '+201112223344',
    createdAt: TestFixtures.baseTime,
    updatedAt: TestFixtures.baseTime,
  );
  List<TripStatusLog> statusLogs = <TripStatusLog>[];
  final List<TripLocationPoint> broadcastedPoints = <TripLocationPoint>[];
  final List<TripLocationPoint> dbSyncedPoints = <TripLocationPoint>[];
  final List<TripStatus> stageTransitions = <TripStatus>[];
  bool cancelledCalled = false;
  void Function(RescueRequest updated)? onTripChangedCallback;

  @override
  Future<RescueRequest?> getActiveTrip(String driverId) async {
    if (activeTrip != null && activeTrip!.status.isActiveWithDriver) {
      return activeTrip;
    }
    return null;
  }

  @override
  Future<RescueRequest?> getTripById(String requestId) async => activeTrip;

  @override
  Future<UserProfile?> getCustomerProfile(String customerId) async =>
      customerProfile;

  @override
  Future<List<TripStatusLog>> getTripStatusLogs(String requestId) async =>
      statusLogs;

  @override
  Future<Map<String, String>> getBreakdownPhotoUrls(List<String> paths) async =>
      <String, String>{};

  @override
  Future<RescueRequest> advanceTripStage({
    required String requestId,
    required TripStatus nextStatus,
    double? lat,
    double? lng,
    String? notes,
    double? finalPrice,
  }) async {
    stageTransitions.add(nextStatus);
    activeTrip = activeTrip!.copyWith(
      status: nextStatus,
      finalPrice: nextStatus == TripStatus.delivered
          ? (finalPrice ?? activeTrip!.estimatedPrice)
          : null,
    );
    return activeTrip!;
  }

  @override
  Future<void> cancelTrip({required String requestId, String? reason}) async {
    cancelledCalled = true;
    activeTrip = activeTrip?.copyWith(status: TripStatus.cancelled);
  }

  @override
  Future<void> openTripChannel(
    String requestId, {
    required void Function(RescueRequest updated) onTripChanged,
  }) async {
    onTripChangedCallback = onTripChanged;
  }

  @override
  Future<void> broadcastLiveLocation({
    required String requestId,
    required TripLocationPoint point,
  }) async {
    broadcastedPoints.add(point);
  }

  @override
  Future<void> syncTripLocationToDb({
    required String requestId,
    required TripLocationPoint point,
  }) async {
    dbSyncedPoints.add(point);
  }

  @override
  Future<void> closeTripChannel() async {}
}

class FakeDriverHistoryRepository implements DriverHistoryRepository {
  List<RescueRequest> trips = <RescueRequest>[];
  List<TripRating> ratings = <TripRating>[];
  List<Complaint> complaints = <Complaint>[];

  @override
  Future<List<RescueRequest>> getDriverTrips(String driverId) async => trips;

  @override
  Future<List<TripRating>> getDriverRatings(String driverId) async => ratings;

  @override
  Future<List<Complaint>> getMyComplaints(String reporterId) async => complaints;

  @override
  Future<Complaint> submitComplaint({
    required String reporterId,
    String? requestId,
    String? reportedUserId,
    required ComplaintCategory category,
    required String subject,
    required String description,
    List<PickedMediaFile> evidenceFiles = const <PickedMediaFile>[],
  }) async {
    final created = Complaint(
      id: 'cmp-${complaints.length + 1}',
      complaintCode: 'CMP-10000${complaints.length + 1}',
      requestId: requestId,
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      category: category,
      subject: subject,
      description: description,
      evidencePaths: evidenceFiles
          .map((e) => '$reporterId/${e.fileName}')
          .toList(growable: false),
      createdAt: TestFixtures.baseTime,
      updatedAt: TestFixtures.baseTime,
    );
    complaints = <Complaint>[created, ...complaints];
    return created;
  }
}

class FakeDriverLocationSource implements DriverLocationSource {
  FakeDriverLocationSource({
    this.initialPosition = const DriverPositionData(
      lat: 30.0444,
      lng: 31.2357,
      heading: 90,
      speedKmh: 40,
    ),
  });

  DriverPositionData initialPosition;
  final StreamController<DriverPositionData> streamController =
      StreamController<DriverPositionData>.broadcast();

  @override
  Future<DriverPositionData> getCurrentPosition() async => initialPosition;

  @override
  Stream<DriverPositionData> getPositionStream({
    int distanceFilterMeters = 5,
    Duration interval = const Duration(seconds: 2),
  }) =>
      streamController.stream;
}

class FakeDriverMediaPicker implements DriverMediaPicker {
  PickedMediaFile? nextFile = PickedMediaFile(
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    fileName: 'doc.jpg',
    contentType: 'image/jpeg',
  );

  @override
  Future<PickedMediaFile?> pickImage({required ImageSource source}) async =>
      nextFile;

  @override
  Future<List<PickedMediaFile>> pickMultiImage() async =>
      nextFile == null ? const <PickedMediaFile>[] : <PickedMediaFile>[nextFile!];
}

class FakeDriverNotificationRepository implements DriverNotificationRepository {
  FakeDriverNotificationRepository({
    List<AppNotification>? initialNotifications,
  }) : notifications = List<AppNotification>.from(
          initialNotifications ?? const <AppNotification>[],
        );

  List<AppNotification> notifications;
  final StreamController<AppNotification> realtimeController =
      StreamController<AppNotification>.broadcast();
  final List<String> markedReadIds = <String>[];
  final List<String> markedAllReadUserIds = <String>[];
  final List<Map<String, String>> registeredTokens = <Map<String, String>>[];
  final List<String> deactivatedTokens = <String>[];

  @override
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  }) async {
    return notifications
        .where((n) => n.userId == userId)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    markedReadIds.add(notificationId);
    notifications = notifications
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    markedAllReadUserIds.add(userId);
    notifications = notifications
        .map((n) => n.userId == userId ? n.copyWith(isRead: true) : n)
        .toList();
  }

  @override
  Stream<AppNotification> watchNotifications(String userId) =>
      realtimeController.stream.where((n) => n.userId == userId);

  @override
  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    registeredTokens.add(<String, String>{
      'userId': userId,
      'token': token,
      'platform': platform,
    });
  }

  @override
  Future<void> deactivateDeviceToken(String token) async {
    deactivatedTokens.add(token);
  }

  @override
  Future<void> disposeSubscriptions() async {}
}

class FakeWenshyGeoService extends WenshyGeoService {
  FakeWenshyGeoService({this.routeResult});

  RoadRouteResult? routeResult;
  final List<({double fromLat, double fromLng, double toLat, double toLng})>
      routeRequests =
      <({double fromLat, double fromLng, double toLat, double toLng})>[];

  @override
  Future<RoadRouteResult> getDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    routeRequests.add((
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    ));
    if (routeResult != null) return routeResult!;

    final midLat = (fromLat + toLat) / 2 + 0.005;
    final midLng = (fromLng + toLng) / 2 - 0.004;
    return RoadRouteResult(
      points: <({double lat, double lng})>[
        (lat: fromLat, lng: fromLng),
        (lat: midLat, lng: midLng),
        (lat: toLat, lng: toLng),
      ],
      distanceKm: 6.4,
      durationMinutes: 14,
      isFallback: false,
    );
  }
}

class FakeDriverExternalLauncher implements DriverExternalLauncher {
  bool nextResult = true;
  final List<String> calledPhones = <String>[];
  final List<({double lat, double lng, ExternalNavProvider provider})>
      navigatedTargets =
      <({double lat, double lng, ExternalNavProvider provider})>[];

  @override
  Future<bool> callPhone(String phone) async {
    calledPhones.add(phone);
    return nextResult;
  }

  @override
  Future<bool> navigateTo({
    required double lat,
    required double lng,
    ExternalNavProvider provider = ExternalNavProvider.googleMaps,
  }) async {
    navigatedTargets.add((lat: lat, lng: lng, provider: provider));
    return nextResult;
  }
}

class FakeDriverPushTokenProvider implements DriverPushTokenProvider {
  FakeDriverPushTokenProvider({this.token, this.error});

  String? token;
  Object? error;

  @override
  Future<String?> getToken() async {
    if (error != null) throw error!;
    return token;
  }
}

DriverAppDependencies createTestDependencies({
  FakeDriverAuthRepository? authRepository,
  FakeDriverOnboardingRepository? onboardingRepository,
  FakeDriverDispatchRepository? dispatchRepository,
  FakeDriverTripRepository? tripRepository,
  FakeDriverHistoryRepository? historyRepository,
  FakeDriverNotificationRepository? notificationRepository,
  FakeDriverLocationSource? locationSource,
  FakeDriverMediaPicker? mediaPicker,
  FakeWenshyGeoService? geoService,
  FakeDriverExternalLauncher? externalLauncher,
  DriverPushTokenProvider? pushTokenProvider,
  LocaleController? localeController,
}) {
  final auth = authRepository ?? FakeDriverAuthRepository();
  final trip = tripRepository ?? FakeDriverTripRepository();
  final notifications =
      notificationRepository ?? FakeDriverNotificationRepository();
  final locale = localeController ?? LocaleController();
  final pushRegistrar = DriverPushTokenRegistrar(
    notificationRepository: notifications,
    tokenProvider: pushTokenProvider ?? const NoOpDriverPushTokenProvider(),
    platformOverride: TargetPlatform.android,
    isWebOverride: false,
  );
  final session = DriverSessionController(
    authRepository: auth,
    tripRepository: trip,
    localeController: locale,
    pushTokenRegistrar: pushRegistrar,
    subscribeToAuthChanges: false,
  );
  final notificationsController = DriverNotificationsController(
    notificationRepository: notifications,
    sessionController: session,
  );
  return DriverAppDependencies(
    authRepository: auth,
    onboardingRepository:
        onboardingRepository ?? FakeDriverOnboardingRepository(),
    dispatchRepository: dispatchRepository ?? FakeDriverDispatchRepository(),
    tripRepository: trip,
    historyRepository: historyRepository ?? FakeDriverHistoryRepository(),
    notificationRepository: notifications,
    locationSource: locationSource ?? FakeDriverLocationSource(),
    mediaPicker: mediaPicker ?? FakeDriverMediaPicker(),
    geoService: geoService ?? FakeWenshyGeoService(),
    externalLauncher: externalLauncher ?? FakeDriverExternalLauncher(),
    pushTokenRegistrar: pushRegistrar,
    localeController: locale,
    sessionController: session,
    notificationsController: notificationsController,
    showMapTiles: false,
  );
}
