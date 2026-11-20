import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';

/// Environment configuration and initialization helpers for Supabase.
abstract final class SupabaseConfig {
  /// Supabase project URL provided via `--dart-define=SUPABASE_URL=...`.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ytwpenavwybfmxawiadj.supabase.co',
  );

  /// Supabase client key (publishable or legacy anon) provided via
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_WC2QHX2G2TdN0jvUAkrM_Q_QT7kYxL5',
  );

  /// Default local Supabase CLI API URL for development fallback.
  static const String defaultLocalUrl = 'http://127.0.0.1:54321';

  /// Whether both [url] and [anonKey] were supplied at compile time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Initializes [Supabase] using compile-time environment values or explicit
  /// overrides.
  ///
  /// Throws a [StateError] if either URL or anonKey resolves to empty.
  static Future<Supabase> initialize({
    String? urlOverride,
    String? anonKeyOverride,
    bool debug = false,
  }) {
    final resolvedUrl = (urlOverride ?? url).trim();
    final resolvedKey = (anonKeyOverride ?? anonKey).trim();

    if (resolvedUrl.isEmpty || resolvedKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Pass '
        '--dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    return Supabase.initialize(
      url: resolvedUrl,
      publishableKey: resolvedKey,
      debug: debug,
    );
  }
}

/// Storage bucket IDs and RLS-compliant object path builders matching
/// `supabase/migrations/20261112213122_rls_and_storage_policies.sql`.
abstract final class StorageBuckets {
  /// Private bucket for driver KYC & compliance documents
  /// (`<driver_id>/<doc_type>/<file>`).
  static const String driverDocuments = 'driver-documents';

  /// Public-read bucket for tow-truck photos (`<driver_id>/<file>`).
  static const String winchPhotos = 'winch-photos';

  /// Private bucket for vehicle breakdown photos
  /// (`<customer_id>/<request_id>/<file>`).
  static const String breakdownPhotos = 'breakdown-photos';

  /// Private bucket for dispute/complaint evidence (`<reporter_id>/<file>`).
  static const String complaintEvidence = 'complaint-evidence';

  /// Builds an RLS-compliant path for [driverDocuments].
  static String driverDocumentPath({
    required String driverId,
    required DocumentType documentType,
    required String fileName,
  }) =>
      '$driverId/${documentType.value}/$fileName';

  /// Builds an RLS-compliant path for [winchPhotos].
  static String winchPhotoPath({
    required String driverId,
    required String fileName,
  }) =>
      '$driverId/$fileName';

  /// Builds an RLS-compliant path for [breakdownPhotos].
  static String breakdownPhotoPath({
    required String customerId,
    required String requestId,
    required String fileName,
  }) =>
      '$customerId/$requestId/$fileName';

  /// Builds an RLS-compliant path for [complaintEvidence].
  static String complaintEvidencePath({
    required String reporterId,
    required String fileName,
  }) =>
      '$reporterId/$fileName';
}

/// Private Realtime topic names and event identifiers matching
/// `private.can_access_realtime_topic` and broadcast triggers in Migration 003.
abstract final class RealtimeTopics {
  /// Private channel for customer + assigned driver live trip updates and GPS
  /// broadcast (`trip:<request_id>`).
  static String trip(String requestId) => 'trip:$requestId';

  /// Private channel for driver incoming dispatch offer broadcasts
  /// (`driver:<driver_id>`).
  static String driver(String driverId) => 'driver:$driverId';

  /// Private presence channel for approved online drivers (`fleet:online`).
  static const String fleetOnline = 'fleet:online';

  /// Standard private channel config required by `realtime.messages` RLS.
  static const RealtimeChannelConfig privateChannelConfig =
      RealtimeChannelConfig(private: true);

  /// Ephemeral broadcast event emitted by the assigned driver on `trip:<id>`.
  static const String driverLocationEvent = 'driver_location';

  /// `realtime.broadcast_changes` event name for row inserts.
  static const String insertEvent = 'INSERT';

  /// `realtime.broadcast_changes` event name for row updates.
  static const String updateEvent = 'UPDATE';

  /// `realtime.broadcast_changes` event name for row deletes.
  static const String deleteEvent = 'DELETE';
}

/// Exact PostgreSQL table names in `public` schema (Migration 002).
abstract final class WenshyTables {
  static const String profiles = 'profiles';
  static const String customerVehicles = 'customer_vehicles';
  static const String winchTypes = 'winch_types';
  static const String drivers = 'drivers';
  static const String driverWinches = 'driver_winches';
  static const String driverDocuments = 'driver_documents';
  static const String rescueRequests = 'rescue_requests';
  static const String dispatchOffers = 'dispatch_offers';
  static const String tripStatusLogs = 'trip_status_logs';
  static const String tripLocationHistory = 'trip_location_history';
  static const String ratings = 'ratings';
  static const String complaints = 'complaints';
  static const String deviceTokens = 'device_tokens';
  static const String notifications = 'notifications';
}

/// Exact PostgreSQL view names in `public` schema (Migration 004).
abstract final class WenshyViews {
  static const String adminDriverApplications = 'v_admin_driver_applications';
  static const String adminActiveTrips = 'v_admin_active_trips';
  static const String adminComplaintsQueue = 'v_admin_complaints_queue';
}

/// Exact PostgreSQL RPC function names in `public` schema (Migration 004).
abstract final class WenshyRpcs {
  static const String calculateWinchQuote = 'calculate_winch_quote';
  static const String findNearestDrivers = 'find_nearest_drivers';
  static const String dispatchRescueRequest = 'dispatch_rescue_request';
  static const String createRescueRequest = 'create_rescue_request';
  static const String acceptRescueOffer = 'accept_rescue_offer';
  static const String rejectRescueOffer = 'reject_rescue_offer';
  static const String driverUpdateTripStage = 'driver_update_trip_stage';
  static const String cancelRescueRequest = 'cancel_rescue_request';
  static const String driverUpdateLocation = 'driver_update_location';
  static const String adminReviewDriver = 'admin_review_driver';
  static const String adminReviewDocument = 'admin_review_document';
  static const String adminResolveComplaint = 'admin_resolve_complaint';
  static const String adminSetUserActive = 'admin_set_user_active';
  static const String adminGetDashboardStats = 'admin_get_dashboard_stats';
  static const String deleteMyAccount = 'delete_my_account';
}
