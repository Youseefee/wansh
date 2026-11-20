/// Domain enums matching PostgreSQL enum types in `public` schema
/// (`supabase/migrations/20261112212957_extensions_and_types.sql`).
library;

T _enumFromValue<T extends Enum>(
  Iterable<T> values,
  String Function(T) getValue,
  Object? raw,
  String typeName,
) {
  final str = raw?.toString();
  if (str != null) {
    for (final v in values) {
      if (getValue(v) == str) {
        return v;
      }
    }
  }
  throw ArgumentError('Unknown $typeName value: $raw');
}

T? _enumTryFromValue<T extends Enum>(
  Iterable<T> values,
  String Function(T) getValue,
  Object? raw,
) {
  final str = raw?.toString();
  if (str == null || str.isEmpty) return null;
  for (final v in values) {
    if (getValue(v) == str) {
      return v;
    }
  }
  return null;
}

/// PostgreSQL `public.app_role`.
enum AppRole {
  customer('customer'),
  driver('driver'),
  admin('admin');

  const AppRole(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static AppRole fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'AppRole');

  static AppRole? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.driver_approval_status`.
enum DriverApprovalStatus {
  pending('pending'),
  underReview('under_review'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  const DriverApprovalStatus(this.value);

  /// Exact SQL enum string value.
  final String value;

  bool get isApproved => this == DriverApprovalStatus.approved;

  bool get canEditDocuments =>
      this == DriverApprovalStatus.pending ||
      this == DriverApprovalStatus.underReview ||
      this == DriverApprovalStatus.rejected;

  String toJson() => value;

  static DriverApprovalStatus fromJson(Object? value) => _enumFromValue(
        values,
        (e) => e.value,
        value,
        'DriverApprovalStatus',
      );

  static DriverApprovalStatus? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.document_type`.
enum DocumentType {
  nationalIdFront('national_id_front'),
  nationalIdBack('national_id_back'),
  driverLicenseFront('driver_license_front'),
  driverLicenseBack('driver_license_back'),
  winchLicenseFront('winch_license_front'),
  winchLicenseBack('winch_license_back'),
  criminalRecord('criminal_record'),
  selfieWithId('selfie_with_id');

  const DocumentType(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static DocumentType fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'DocumentType');

  static DocumentType? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.document_review_status`.
enum DocumentReviewStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const DocumentReviewStatus(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static DocumentReviewStatus fromJson(Object? value) => _enumFromValue(
        values,
        (e) => e.value,
        value,
        'DocumentReviewStatus',
      );

  static DocumentReviewStatus? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.vehicle_category`.
enum VehicleCategory {
  sedan('sedan'),
  hatchback('hatchback'),
  suv('suv'),
  pickup('pickup'),
  van('van'),
  luxuryLowClearance('luxury_low_clearance'),
  motorcycle('motorcycle'),
  lightTruck('light_truck');

  const VehicleCategory(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static VehicleCategory fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'VehicleCategory');

  static VehicleCategory? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.trip_status`.
enum TripStatus {
  searching('searching'),
  driverAssigned('driver_assigned'),
  enRouteToPickup('en_route_to_pickup'),
  arrivedAtPickup('arrived_at_pickup'),
  vehicleLoaded('vehicle_loaded'),
  enRouteToDropoff('en_route_to_dropoff'),
  delivered('delivered'),
  cancelled('cancelled'),
  expired('expired');

  const TripStatus(this.value);

  /// Exact SQL enum string value.
  final String value;

  /// Ordered 6-step assigned-trip progression stages shown in trip trackers.
  static const List<TripStatus> activeTimelineSteps = <TripStatus>[
    TripStatus.driverAssigned,
    TripStatus.enRouteToPickup,
    TripStatus.arrivedAtPickup,
    TripStatus.vehicleLoaded,
    TripStatus.enRouteToDropoff,
    TripStatus.delivered,
  ];

  /// Whether no further transitions are possible from this status.
  bool get isTerminal =>
      this == TripStatus.delivered ||
      this == TripStatus.cancelled ||
      this == TripStatus.expired;

  /// Whether a driver is actively assigned and executing this trip.
  bool get isActiveWithDriver =>
      this == TripStatus.driverAssigned ||
      this == TripStatus.enRouteToPickup ||
      this == TripStatus.arrivedAtPickup ||
      this == TripStatus.vehicleLoaded ||
      this == TripStatus.enRouteToDropoff;

  /// Whether non-admin participants may cancel this trip via
  /// `cancel_rescue_request` (allowed up to `arrived_at_pickup`).
  bool get isCancellable =>
      this == TripStatus.searching ||
      this == TripStatus.driverAssigned ||
      this == TripStatus.enRouteToPickup ||
      this == TripStatus.arrivedAtPickup;

  /// Next standard stage for the driver state machine in
  /// `driver_update_trip_stage`, or `null` if none.
  TripStatus? get nextDriverStage => switch (this) {
        TripStatus.driverAssigned => TripStatus.enRouteToPickup,
        TripStatus.enRouteToPickup => TripStatus.arrivedAtPickup,
        TripStatus.arrivedAtPickup => TripStatus.vehicleLoaded,
        TripStatus.vehicleLoaded => TripStatus.enRouteToDropoff,
        TripStatus.enRouteToDropoff => TripStatus.delivered,
        _ => null,
      };

  String toJson() => value;

  static TripStatus fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'TripStatus');

  static TripStatus? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.offer_status`.
enum OfferStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  expired('expired'),
  cancelled('cancelled');

  const OfferStatus(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static OfferStatus fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'OfferStatus');

  static OfferStatus? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.payment_method`.
enum PaymentMethod {
  cash('cash'),
  card('card'),
  wallet('wallet');

  const PaymentMethod(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static PaymentMethod fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'PaymentMethod');

  static PaymentMethod? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.payment_status`.
enum PaymentStatus {
  pending('pending'),
  paid('paid'),
  refunded('refunded'),
  failed('failed');

  const PaymentStatus(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static PaymentStatus fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'PaymentStatus');

  static PaymentStatus? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.complaint_category`.
enum ComplaintCategory {
  pricing('pricing'),
  driverBehavior('driver_behavior'),
  customerBehavior('customer_behavior'),
  vehicleDamage('vehicle_damage'),
  delay('delay'),
  appIssue('app_issue'),
  other('other');

  const ComplaintCategory(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static ComplaintCategory fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'ComplaintCategory');

  static ComplaintCategory? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}

/// PostgreSQL `public.complaint_status`.
enum ComplaintStatus {
  open('open'),
  inProgress('in_progress'),
  resolved('resolved'),
  dismissed('dismissed');

  const ComplaintStatus(this.value);

  /// Exact SQL enum string value.
  final String value;

  String toJson() => value;

  static ComplaintStatus fromJson(Object? value) =>
      _enumFromValue(values, (e) => e.value, value, 'ComplaintStatus');

  static ComplaintStatus? tryFromJson(Object? value) =>
      _enumTryFromValue(values, (e) => e.value, value);
}
