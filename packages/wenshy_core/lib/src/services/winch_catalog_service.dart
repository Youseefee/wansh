import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/nearby_driver.dart';
import '../models/winch_quote.dart';
import '../models/winch_type.dart';

/// Service for browsing tow-truck categories (`winch_types`), computing
/// server-authoritative quotations (`calculate_winch_quote`), and querying
/// nearby online drivers (`find_nearest_drivers`).
class WinchCatalogService {
  const WinchCatalogService({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Fetches all active [WinchType] entries sorted by `sort_order`.
  Future<List<WinchType>> getActiveWinchTypes() async {
    final rows = await _supabase
        .from(WenshyTables.winchTypes)
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (rows as List<dynamic>)
        .map((row) => WinchType.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  /// Fetches a single [WinchType] by its UUID, or `null` if not found.
  Future<WinchType?> getWinchTypeById(String id) async {
    final row = await _supabase
        .from(WenshyTables.winchTypes)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return WinchType.fromJson(Map<String, dynamic>.from(row));
  }

  /// Calls `public.calculate_winch_quote` RPC to obtain an authoritative
  /// distance & fare quotation.
  Future<WinchQuote> calculateQuote({
    required String winchTypeId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    double? routeDistanceKm,
  }) async {
    final response = await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.calculateWinchQuote,
      params: <String, dynamic>{
        'p_winch_type_id': winchTypeId,
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_dropoff_lat': dropoffLat,
        'p_dropoff_lng': dropoffLng,
        'p_route_distance_km': ?routeDistanceKm,
      },
    );

    return WinchQuote.fromJson(Map<String, dynamic>.from(response));
  }

  /// Calls `public.find_nearest_drivers` RPC to find approved, online,
  /// available drivers within [radiusMeters] operating a verified [winchTypeId].
  Future<List<NearbyDriver>> findNearestDrivers({
    required double pickupLat,
    required double pickupLng,
    required String winchTypeId,
    int radiusMeters = 15000,
    int limit = 10,
    String? excludeRequestId,
  }) async {
    final rows = await _supabase.rpc<List<dynamic>>(
      WenshyRpcs.findNearestDrivers,
      params: <String, dynamic>{
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_winch_type_id': winchTypeId,
        'p_radius_meters': radiusMeters,
        'p_limit': limit,
        'p_exclude_request_id': ?excludeRequestId,
      },
    );

    return rows
        .map(
          (row) => NearbyDriver.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }
}
