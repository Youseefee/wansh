import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

import 'models.dart';

/// Handle representing an active private `trip:<request_id>` Realtime
/// subscription.
abstract class TripRealtimeSubscription {
  Future<void> dispose();
}

/// Parses payloads arriving on the private `trip:<request_id>` Realtime channel.
abstract final class RescueRequestRealtimeParser {
  /// Extracts a [RescueRequest] from a `realtime.broadcast_changes` payload
  /// (whether nested under `payload['payload']['record']` or direct).
  static RescueRequest? parseRescueRequestUpdate(Map<String, dynamic> raw) {
    final inner = raw['payload'] is Map
        ? Map<String, dynamic>.from(raw['payload'] as Map)
        : raw;

    final candidate = inner['record'] ?? inner['new'] ?? inner;
    if (candidate is! Map) return null;

    final map = Map<String, dynamic>.from(candidate);
    if (!map.containsKey('id') || !map.containsKey('status')) {
      return null;
    }

    try {
      return RescueRequest.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Extracts a [TripLocationPoint] from a `driver_location` ephemeral
  /// broadcast payload.
  static TripLocationPoint? parseDriverLocation(Map<String, dynamic> raw) {
    final inner = raw['payload'] is Map
        ? Map<String, dynamic>.from(raw['payload'] as Map)
        : raw;

    if (!inner.containsKey('lat') || !inner.containsKey('lng')) {
      return null;
    }

    try {
      return TripLocationPoint.fromJson(inner);
    } catch (_) {
      return null;
    }
  }
}

/// Repository for rescue requests, breakdown photo uploads, Wave dispatch,
/// trip cancellation, driver/winch lookup, and private Realtime tracking.
abstract class RescueRequestRepository {
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
  });

  /// Uploads breakdown photos to `breakdown-photos/<customer_id>/<request_id>/<file>`
  /// and updates `rescue_requests.breakdown_photo_paths`.
  Future<List<String>> uploadAndAttachBreakdownPhotos({
    required String customerId,
    required String requestId,
    required List<SelectedPhotoBytes> photos,
  });

  Future<RescueRequest?> getRescueRequestById(String requestId);

  Future<List<RescueRequest>> getCustomerTrips(String customerId);

  Future<RescueRequest?> getLatestActiveTrip(String customerId);

  Future<DriverProfile?> getAssignedDriverInfo(String driverId);

  Future<DriverWinch?> getAssignedWinchInfo(String winchId);

  Future<List<TripStatusLog>> getTripStatusLogs(String requestId);

  Future<TripLocationPoint?> getLatestDriverLocation(String requestId);

  Future<DispatchResult> dispatchNextWave({
    required String requestId,
    int radiusMeters = 25000,
    int waveNumber = 2,
    int batchSize = 5,
    int offerTtlSeconds = 45,
  });

  Future<bool> cancelRescueRequest({
    required String requestId,
    String? reason,
  });

  Future<Map<String, String>> getBreakdownPhotoSignedUrls(List<String> paths);

  TripRealtimeSubscription subscribeToTrip({
    required String requestId,
    required void Function(RescueRequest? updated, Map<String, dynamic> raw)
        onTripUpdate,
    required void Function(TripLocationPoint location) onDriverLocation,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  });
}

class _SupabaseTripSubscription implements TripRealtimeSubscription {
  _SupabaseTripSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  Future<void> dispose() async {
    await _client.removeChannel(_channel);
  }
}

/// Supabase implementation of [RescueRequestRepository].
class SupabaseRescueRequestRepository implements RescueRequestRepository {
  SupabaseRescueRequestRepository({
    SupabaseClient? client,
    StorageService? storageService,
  })  : _client = client,
        _storage = storageService ?? StorageService(client: client);

  final SupabaseClient? _client;
  final StorageService _storage;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

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
    final response = await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.createRescueRequest,
      params: <String, dynamic>{
        'p_winch_type_id': winchTypeId,
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_pickup_address': pickupAddress.trim(),
        'p_dropoff_lat': dropoffLat,
        'p_dropoff_lng': dropoffLng,
        'p_dropoff_address': dropoffAddress.trim(),
        'p_customer_vehicle_id': ?customerVehicleId,
        if (vehicleMake != null && vehicleMake.trim().isNotEmpty)
          'p_vehicle_make': vehicleMake.trim(),
        if (vehicleModel != null && vehicleModel.trim().isNotEmpty)
          'p_vehicle_model': vehicleModel.trim(),
        'p_vehicle_year': ?vehicleYear,
        if (vehicleColor != null && vehicleColor.trim().isNotEmpty)
          'p_vehicle_color': vehicleColor.trim(),
        if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty)
          'p_vehicle_plate': vehiclePlate.trim(),
        'p_vehicle_category': vehicleCategory.toJson(),
        if (breakdownReason != null && breakdownReason.trim().isNotEmpty)
          'p_breakdown_reason': breakdownReason.trim(),
        if (breakdownNotes != null && breakdownNotes.trim().isNotEmpty)
          'p_breakdown_notes': breakdownNotes.trim(),
        'p_breakdown_photo_paths': breakdownPhotoPaths,
        'p_payment_method': paymentMethod.toJson(),
        'p_route_distance_km': ?routeDistanceKm,
        'p_initial_radius_meters': initialRadiusMeters,
      },
    );

    return CreateRescueRequestResult.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<List<String>> uploadAndAttachBreakdownPhotos({
    required String customerId,
    required String requestId,
    required List<SelectedPhotoBytes> photos,
  }) async {
    if (photos.isEmpty) return const <String>[];

    final uploadedPaths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final safeName = '${DateTime.now().millisecondsSinceEpoch}_${i}_${photo.fileName}';
      final path = await _storage.uploadBreakdownPhoto(
        customerId: customerId,
        requestId: requestId,
        fileName: safeName,
        bytes: photo.bytes,
        contentType: photo.contentType,
      );
      uploadedPaths.add(path);
    }

    await _supabase
        .from(WenshyTables.rescueRequests)
        .update(<String, dynamic>{'breakdown_photo_paths': uploadedPaths})
        .eq('id', requestId)
        .eq('customer_id', customerId);

    return uploadedPaths;
  }

  @override
  Future<RescueRequest?> getRescueRequestById(String requestId) async {
    final row = await _supabase
        .from(WenshyTables.rescueRequests)
        .select()
        .eq('id', requestId)
        .maybeSingle();

    if (row == null) return null;
    return RescueRequest.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<RescueRequest>> getCustomerTrips(String customerId) async {
    final rows = await _supabase
        .from(WenshyTables.rescueRequests)
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => RescueRequest.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<RescueRequest?> getLatestActiveTrip(String customerId) async {
    final row = await _supabase
        .from(WenshyTables.rescueRequests)
        .select()
        .eq('customer_id', customerId)
        .not('status', 'in', '(delivered,cancelled,expired)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return RescueRequest.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<DriverProfile?> getAssignedDriverInfo(String driverId) async {
    final row = await _supabase
        .from(WenshyTables.drivers)
        .select('*, profiles!drivers_id_fkey(*)')
        .eq('id', driverId)
        .maybeSingle();

    if (row == null) return null;
    return DriverProfile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<DriverWinch?> getAssignedWinchInfo(String winchId) async {
    final row = await _supabase
        .from(WenshyTables.driverWinches)
        .select('*, winch_types(*)')
        .eq('id', winchId)
        .maybeSingle();

    if (row == null) return null;
    return DriverWinch.fromJson(Map<String, dynamic>.from(row));
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
          (row) => TripStatusLog.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<TripLocationPoint?> getLatestDriverLocation(String requestId) async {
    final row = await _supabase
        .from(WenshyTables.tripLocationHistory)
        .select()
        .eq('request_id', requestId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return TripLocationPoint.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<DispatchResult> dispatchNextWave({
    required String requestId,
    int radiusMeters = 25000,
    int waveNumber = 2,
    int batchSize = 5,
    int offerTtlSeconds = 45,
  }) async {
    final response = await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.dispatchRescueRequest,
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_radius_meters': radiusMeters,
        'p_wave_number': waveNumber,
        'p_batch_size': batchSize,
        'p_offer_ttl_seconds': offerTtlSeconds,
      },
    );

    return DispatchResult.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<bool> cancelRescueRequest({
    required String requestId,
    String? reason,
  }) async {
    final response = await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.cancelRescueRequest,
      params: <String, dynamic>{
        'p_request_id': requestId,
        if (reason != null && reason.trim().isNotEmpty)
          'p_reason': reason.trim(),
      },
    );

    final map = Map<String, dynamic>.from(response);
    return map['cancelled'] == true;
  }

  @override
  Future<Map<String, String>> getBreakdownPhotoSignedUrls(List<String> paths) {
    return _storage.createSignedUrls(
      bucket: StorageBuckets.breakdownPhotos,
      paths: paths,
    );
  }

  @override
  TripRealtimeSubscription subscribeToTrip({
    required String requestId,
    required void Function(RescueRequest? updated, Map<String, dynamic> raw)
        onTripUpdate,
    required void Function(TripLocationPoint location) onDriverLocation,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    final channel = _supabase.channel(
      RealtimeTopics.trip(requestId),
      opts: RealtimeTopics.privateChannelConfig,
    );

    channel
        .onBroadcast(
          event: RealtimeTopics.updateEvent,
          callback: (payload) {
            final parsed =
                RescueRequestRealtimeParser.parseRescueRequestUpdate(payload);
            onTripUpdate(parsed, payload);
          },
        )
        .onBroadcast(
          event: RealtimeTopics.insertEvent,
          callback: (payload) {
            final parsed =
                RescueRequestRealtimeParser.parseRescueRequestUpdate(payload);
            onTripUpdate(parsed, payload);
          },
        )
        .onBroadcast(
          event: RealtimeTopics.driverLocationEvent,
          callback: (payload) {
            final point =
                RescueRequestRealtimeParser.parseDriverLocation(payload);
            if (point != null) {
              onDriverLocation(point);
            }
          },
        )
        .subscribe(onStatus);

    return _SupabaseTripSubscription(_supabase, channel);
  }
}
