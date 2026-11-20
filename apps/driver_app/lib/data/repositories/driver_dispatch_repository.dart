import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Parsed outcome from `public.accept_rescue_offer` RPC.
@immutable
class AcceptOfferResult {
  const AcceptOfferResult({
    required this.accepted,
    this.requestId,
    this.requestCode,
    this.status,
    this.reason,
  });

  final bool accepted;
  final String? requestId;
  final String? requestCode;
  final TripStatus? status;
  final String? reason;

  factory AcceptOfferResult.fromJson(Map<String, dynamic> json) {
    return AcceptOfferResult(
      accepted: JsonParsers.asBool(json['accepted'], defaultValue: false),
      requestId: json['request_id'] as String?,
      requestCode: json['request_code'] as String?,
      status: TripStatus.tryFromJson(json['status']),
      reason: json['reason'] as String?,
    );
  }
}

/// Realtime event emitted on the private `driver:<driver_id>` dispatch channel.
@immutable
class DispatchOfferEvent {
  const DispatchOfferEvent({
    required this.eventType,
    required this.offer,
  });

  final String eventType; // 'INSERT' or 'UPDATE'
  final DispatchOffer offer;
}

/// Extracts a `record` map from `realtime.broadcast_changes` payloads.
Map<String, dynamic>? extractBroadcastRecord(Map<String, dynamic> payload) {
  final direct = payload['record'];
  if (direct is Map) {
    return Map<String, dynamic>.from(direct);
  }
  final nested = payload['payload'];
  if (nested is Map && nested['record'] is Map) {
    return Map<String, dynamic>.from(nested['record'] as Map);
  }
  if (payload.containsKey('id')) {
    return Map<String, dynamic>.from(payload);
  }
  return null;
}

/// Repository handling driver online presence (`fleet:online`), GPS location
/// sync (`driver_update_location`), private dispatch listening
/// (`driver:<driver_id>`), and offer acceptance/rejection RPCs.
abstract class DriverDispatchRepository {
  Future<void> syncLocationAndOnlineStatus({
    required double lat,
    required double lng,
    double? heading,
    double? speedKmh,
    bool? isOnline,
    String? activeRequestId,
  });

  Future<void> joinOnlinePresence({
    required String driverId,
    required double lat,
    required double lng,
  });

  Future<void> leaveOnlinePresence();

  Future<List<DispatchOffer>> getPendingOffers(String driverId);
  Future<DispatchOffer?> getOfferById(String offerId);

  Stream<DispatchOfferEvent> watchDriverOffers(String driverId);

  Future<AcceptOfferResult> acceptOffer(String offerId);
  Future<bool> rejectOffer(String offerId, {String? reason});

  Future<void> disposeSubscriptions();
}

/// Supabase-backed implementation of [DriverDispatchRepository].
class SupabaseDriverDispatchRepository implements DriverDispatchRepository {
  SupabaseDriverDispatchRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _dispatchChannel;
  StreamController<DispatchOfferEvent>? _offersController;

  @override
  Future<void> syncLocationAndOnlineStatus({
    required double lat,
    required double lng,
    double? heading,
    double? speedKmh,
    bool? isOnline,
    String? activeRequestId,
  }) async {
    await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.driverUpdateLocation,
      params: <String, dynamic>{
        'p_lat': lat,
        'p_lng': lng,
        'p_heading': ?heading,
        'p_speed_kmh': ?speedKmh,
        'p_is_online': ?isOnline,
        'p_active_request_id': ?activeRequestId,
      },
    );
  }

  @override
  Future<void> joinOnlinePresence({
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    await leaveOnlinePresence();

    final channel = _supabase.channel(
      RealtimeTopics.fleetOnline,
      opts: RealtimeTopics.privateChannelConfig,
    );
    _presenceChannel = channel;

    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed &&
          _presenceChannel == channel) {
        try {
          await channel.track(<String, dynamic>{
            'driver_id': driverId,
            'lat': lat,
            'lng': lng,
            'online_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {
          // Presence track may fail transiently on reconnect; location RPC
          // remains authoritative for dispatch matching.
        }
      }
    });
  }

  @override
  Future<void> leaveOnlinePresence() async {
    final channel = _presenceChannel;
    _presenceChannel = null;
    if (channel != null) {
      try {
        await channel.untrack();
      } catch (_) {}
      await _supabase.removeChannel(channel);
    }
  }

  @override
  Future<List<DispatchOffer>> getPendingOffers(String driverId) async {
    final rows = await _supabase
        .from(WenshyTables.dispatchOffers)
        .select('*, rescue_requests(*)')
        .eq('driver_id', driverId)
        .eq('status', OfferStatus.pending.value)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => DispatchOffer.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<DispatchOffer?> getOfferById(String offerId) async {
    final row = await _supabase
        .from(WenshyTables.dispatchOffers)
        .select('*, rescue_requests(*)')
        .eq('id', offerId)
        .maybeSingle();

    if (row == null) return null;
    return DispatchOffer.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Stream<DispatchOfferEvent> watchDriverOffers(String driverId) {
    unawaited(_closeDispatchChannelOnly());

    final controller = StreamController<DispatchOfferEvent>.broadcast();
    _offersController = controller;

    final channel = _supabase.channel(
      RealtimeTopics.driver(driverId),
      opts: RealtimeTopics.privateChannelConfig,
    );
    _dispatchChannel = channel;

    void handlePayload(String eventType, Map<String, dynamic> payload) async {
      final record = extractBroadcastRecord(payload);
      if (record == null || controller.isClosed) return;

      try {
        var offer = DispatchOffer.fromJson(record);
        if (offer.status == OfferStatus.pending &&
            offer.rescueRequest == null) {
          final hydrated = await getOfferById(offer.id);
          if (hydrated != null) {
            offer = hydrated;
          }
        }
        if (!controller.isClosed) {
          controller.add(
            DispatchOfferEvent(eventType: eventType, offer: offer),
          );
        }
      } catch (_) {
        // Ignore malformed broadcast frames safely.
      }
    }

    channel
        .onBroadcast(
          event: RealtimeTopics.insertEvent,
          callback: (payload) =>
              handlePayload(RealtimeTopics.insertEvent, payload),
        )
        .onBroadcast(
          event: RealtimeTopics.updateEvent,
          callback: (payload) =>
              handlePayload(RealtimeTopics.updateEvent, payload),
        )
        .subscribe();

    return controller.stream;
  }

  Future<void> _closeDispatchChannelOnly() async {
    final channel = _dispatchChannel;
    final controller = _offersController;
    _dispatchChannel = null;
    _offersController = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    if (channel != null) {
      await _supabase.removeChannel(channel);
    }
  }

  @override
  Future<AcceptOfferResult> acceptOffer(String offerId) async {
    final response = await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.acceptRescueOffer,
      params: <String, dynamic>{'p_offer_id': offerId},
    );
    return AcceptOfferResult.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<bool> rejectOffer(String offerId, {String? reason}) async {
    final response = await _supabase.rpc<Map<String, dynamic>>(
      WenshyRpcs.rejectRescueOffer,
      params: <String, dynamic>{
        'p_offer_id': offerId,
        if (reason != null && reason.trim().isNotEmpty)
          'p_reason': reason.trim(),
      },
    );
    return JsonParsers.asBool(response['rejected'], defaultValue: false);
  }

  @override
  Future<void> disposeSubscriptions() async {
    await leaveOnlinePresence();
    await _closeDispatchChannelOnly();
  }
}
