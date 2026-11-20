import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'driver_dispatch_repository.dart';

/// Repository for executing an active rescue trip, advancing stages via
/// `driver_update_trip_stage`, broadcasting live GPS coordinates over private
/// `trip:<request_id>`, and syncing throttled location breadcrumbs.
abstract class DriverTripRepository {
  Future<RescueRequest?> getActiveTrip(String driverId);
  Future<RescueRequest?> getTripById(String requestId);
  Future<UserProfile?> getCustomerProfile(String customerId);
  Future<List<TripStatusLog>> getTripStatusLogs(String requestId);
  Future<Map<String, String>> getBreakdownPhotoUrls(List<String> paths);

  Future<RescueRequest> advanceTripStage({
    required String requestId,
    required TripStatus nextStatus,
    double? lat,
    double? lng,
    String? notes,
    double? finalPrice,
  });

  Future<void> cancelTrip({
    required String requestId,
    String? reason,
  });

  Future<void> openTripChannel(
    String requestId, {
    required void Function(RescueRequest updated) onTripChanged,
  });

  Future<void> broadcastLiveLocation({
    required String requestId,
    required TripLocationPoint point,
  });

  Future<void> syncTripLocationToDb({
    required String requestId,
    required TripLocationPoint point,
  });

  Future<void> closeTripChannel();
}

/// Supabase-backed implementation of [DriverTripRepository].
class SupabaseDriverTripRepository implements DriverTripRepository {
  SupabaseDriverTripRepository({
    SupabaseClient? client,
    StorageService? storageService,
  })  : _supabase = client ?? Supabase.instance.client,
        _storageService = storageService ?? StorageService(client: client);

  final SupabaseClient _supabase;
  final StorageService _storageService;

  RealtimeChannel? _tripChannel;
  String? _activeTripChannelId;

  static final List<String> _activeStageValues = <String>[
    TripStatus.driverAssigned.value,
    TripStatus.enRouteToPickup.value,
    TripStatus.arrivedAtPickup.value,
    TripStatus.vehicleLoaded.value,
    TripStatus.enRouteToDropoff.value,
  ];

  @override
  Future<RescueRequest?> getActiveTrip(String driverId) async {
    final row = await _supabase
        .from(WenshyTables.rescueRequests)
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', _activeStageValues)
        .order('accepted_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return RescueRequest.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<RescueRequest?> getTripById(String requestId) async {
    final row = await _supabase
        .from(WenshyTables.rescueRequests)
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (row == null) return null;
    return RescueRequest.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<UserProfile?> getCustomerProfile(String customerId) async {
    final row = await _supabase
        .from(WenshyTables.profiles)
        .select()
        .eq('id', customerId)
        .maybeSingle();

    if (row == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<TripStatusLog>> getTripStatusLogs(String requestId) async {
    final rows = await _supabase
        .from(WenshyTables.tripStatusLogs)
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .map(
          (row) =>
              TripStatusLog.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, String>> getBreakdownPhotoUrls(List<String> paths) {
    return _storageService.createSignedUrls(
      bucket: StorageBuckets.breakdownPhotos,
      paths: paths,
    );
  }

  @override
  Future<RescueRequest> advanceTripStage({
    required String requestId,
    required TripStatus nextStatus,
    double? lat,
    double? lng,
    String? notes,
    double? finalPrice,
  }) async {
    await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.driverUpdateTripStage,
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_new_status': nextStatus.value,
        'p_lat': ?lat,
        'p_lng': ?lng,
        if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
        'p_final_price': ?finalPrice,
      },
    );

    final refreshed = await getTripById(requestId);
    if (refreshed == null) {
      throw StateError('Updated rescue request $requestId not found.');
    }
    return refreshed;
  }

  @override
  Future<void> cancelTrip({
    required String requestId,
    String? reason,
  }) async {
    await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.cancelRescueRequest,
      params: <String, dynamic>{
        'p_request_id': requestId,
        if (reason != null && reason.trim().isNotEmpty)
          'p_reason': reason.trim(),
      },
    );
  }

  @override
  Future<void> openTripChannel(
    String requestId, {
    required void Function(RescueRequest updated) onTripChanged,
  }) async {
    if (_activeTripChannelId == requestId && _tripChannel != null) {
      return;
    }
    await closeTripChannel();

    final channel = _supabase.channel(
      RealtimeTopics.trip(requestId),
      opts: RealtimeTopics.privateChannelConfig,
    );
    _tripChannel = channel;
    _activeTripChannelId = requestId;

    void handleTripBroadcast(Map<String, dynamic> payload) {
      final record = extractBroadcastRecord(payload);
      if (record == null) return;
      try {
        onTripChanged(RescueRequest.fromJson(record));
      } catch (_) {}
    }

    channel
        .onBroadcast(
          event: RealtimeTopics.updateEvent,
          callback: handleTripBroadcast,
        )
        .onBroadcast(
          event: RealtimeTopics.insertEvent,
          callback: handleTripBroadcast,
        )
        .subscribe();
  }

  @override
  Future<void> broadcastLiveLocation({
    required String requestId,
    required TripLocationPoint point,
  }) async {
    final channel = _tripChannel;
    if (channel == null || _activeTripChannelId != requestId) return;

    await channel.sendBroadcastMessage(
      event: RealtimeTopics.driverLocationEvent,
      payload: point.toBroadcastJson(),
    );
  }

  @override
  Future<void> syncTripLocationToDb({
    required String requestId,
    required TripLocationPoint point,
  }) async {
    await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.driverUpdateLocation,
      params: <String, dynamic>{
        'p_lat': point.lat,
        'p_lng': point.lng,
        if (point.heading != null) 'p_heading': point.heading,
        if (point.speedKmh != null) 'p_speed_kmh': point.speedKmh,
        'p_active_request_id': requestId,
      },
    );
  }

  @override
  Future<void> closeTripChannel() async {
    final channel = _tripChannel;
    _tripChannel = null;
    _activeTripChannelId = null;
    if (channel != null) {
      await _supabase.removeChannel(channel);
    }
  }
}
