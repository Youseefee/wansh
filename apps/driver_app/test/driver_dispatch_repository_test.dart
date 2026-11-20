import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';
import 'package:wenshy_driver/data/repositories/driver_dispatch_repository.dart';

class _FakeRealtimeChannel implements RealtimeChannel {
  _FakeRealtimeChannel(this.name, this.opts);

  final String name;
  final RealtimeChannelConfig opts;
  final Map<String, List<void Function(Map<String, dynamic>)>>
      broadcastCallbacks = <String, List<void Function(Map<String, dynamic>)>>{};
  bool subscribed = false;

  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic> payload) callback,
  }) {
    broadcastCallbacks.putIfAbsent(
      event,
      () => <void Function(Map<String, dynamic>)>[],
    ).add(callback);
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    subscribed = true;
    callback?.call(RealtimeSubscribeStatus.subscribed, null);
    return this;
  }

  void emitBroadcast(String event, Map<String, dynamic> payload) {
    final callbacks = broadcastCallbacks[event];
    if (callbacks == null) return;
    for (final cb in callbacks) {
      cb(payload);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSupabaseClient implements SupabaseClient {
  final List<_FakeRealtimeChannel> createdChannels = <_FakeRealtimeChannel>[];
  final List<RealtimeChannel> removedChannels = <RealtimeChannel>[];
  Completer<void>? removeGate;

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final ch = _FakeRealtimeChannel(name, opts);
    createdChannels.add(ch);
    return ch;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removedChannels.add(channel);
    final gate = removeGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SupabaseDriverDispatchRepository', () {
    test(
        're-subscribing watchDriverOffers closes old stream without closing new stream during async removeChannel',
        () async {
      final client = _FakeSupabaseClient();
      final repo = SupabaseDriverDispatchRepository(client: client);
      addTearDown(repo.disposeSubscriptions);

      // Pause removeChannel to expose any async close race on re-subscription.
      final removeGate = Completer<void>();
      client.removeGate = removeGate;

      final firstEvents = <DispatchOfferEvent>[];
      var firstDone = false;
      final sub1 = repo.watchDriverOffers('driver-1').listen(
            firstEvents.add,
            onDone: () => firstDone = true,
          );
      addTearDown(sub1.cancel);

      expect(client.createdChannels, hasLength(1));
      final ch1 = client.createdChannels.first;
      expect(ch1.name, RealtimeTopics.driver('driver-1'));
      expect(ch1.opts.private, isTrue);
      expect(ch1.subscribed, isTrue);

      // Re-subscribe while channel #1 is still open and removeChannel will yield.
      final secondEvents = <DispatchOfferEvent>[];
      var secondDone = false;
      final sub2 = repo.watchDriverOffers('driver-1').listen(
            secondEvents.add,
            onDone: () => secondDone = true,
          );
      addTearDown(sub2.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(firstDone, isTrue);
      expect(client.createdChannels, hasLength(2));

      // Now let async removeChannel(ch1) finish — stream #2 must stay open.
      removeGate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(secondDone, isFalse);
      expect(client.removedChannels, <_FakeRealtimeChannel>[ch1]);

      final offerPayload = <String, dynamic>{
        'payload': <String, dynamic>{
          'record': <String, dynamic>{
            'id': 'offer-2',
            'request_id': 'req-2',
            'driver_id': 'driver-1',
            'winch_id': 'winch-1',
            'distance_meters': 1500,
            'eta_minutes': 4,
            'wave_number': 1,
            'status': 'rejected',
            'expires_at': DateTime.utc(2026, 11, 12, 18, 5, 0)
                .toIso8601String(),
            'created_at': DateTime.utc(2026, 11, 12, 18, 0, 0)
                .toIso8601String(),
            'updated_at': DateTime.utc(2026, 11, 12, 18, 0, 10)
                .toIso8601String(),
          },
        },
      };

      final ch2 = client.createdChannels[1];
      ch2.emitBroadcast(RealtimeTopics.updateEvent, offerPayload);
      await Future<void>.delayed(Duration.zero);

      expect(firstEvents, isEmpty);
      expect(secondEvents, hasLength(1));
      expect(secondEvents.first.eventType, RealtimeTopics.updateEvent);
      expect(secondEvents.first.offer.id, 'offer-2');
      expect(secondEvents.first.offer.status, OfferStatus.rejected);

      await repo.disposeSubscriptions();
      expect(secondDone, isTrue);
    });
  });
}
