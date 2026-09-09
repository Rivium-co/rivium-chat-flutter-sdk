import 'dart:async';

import 'package:centrifuge/centrifuge.dart' as centrifuge;
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat/src/services/realtime_service.dart';

/// A stand-in for Centrifuge's client that keeps the one rule that matters
/// here: a channel name may be registered only once at a time, and
/// `newSubscription` throws while it is taken. That is the exact behaviour
/// behind the production crash.
class _FakeClient implements centrifuge.Client {
  final Map<String, _FakeSubscription> registry = {};

  /// How long an unsubscribe takes to come back. Backgrounding iOS suspends
  /// the socket, so this round-trip can stall — which is what widened the
  /// race window enough to hit in production.
  Duration unsubscribeDelay = Duration.zero;

  /// Channels the "server" should reject, to simulate a failed subscribe.
  final Set<String> rejectChannels = {};

  int newSubscriptionCalls = 0;

  final _connecting = StreamController<centrifuge.ConnectingEvent>.broadcast();
  final _connected = StreamController<centrifuge.ConnectedEvent>.broadcast();
  final _disconnected = StreamController<centrifuge.DisconnectedEvent>.broadcast();
  final _clientError = StreamController<centrifuge.ErrorEvent>.broadcast();

  @override
  Stream<centrifuge.ConnectingEvent> get connecting => _connecting.stream;
  @override
  Stream<centrifuge.ConnectedEvent> get connected => _connected.stream;
  @override
  Stream<centrifuge.DisconnectedEvent> get disconnected => _disconnected.stream;
  @override
  Stream<centrifuge.ErrorEvent> get error => _clientError.stream;

  @override
  centrifuge.Subscription newSubscription(String channel,
      [centrifuge.SubscriptionConfig? config]) {
    newSubscriptionCalls++;
    if (registry.containsKey(channel)) {
      throw Exception(
          "Subscription to a channel already exists in client's internal registry");
    }
    final sub = _FakeSubscription(this, channel);
    registry[channel] = sub;
    return sub;
  }

  @override
  Future<void> removeSubscription(centrifuge.Subscription subscription) async {
    registry.remove((subscription as _FakeSubscription).channel);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  noSuchMethod(Invocation invocation) => _unsupported(invocation);
}

class _FakeSubscription implements centrifuge.Subscription {
  _FakeSubscription(this._client, this.channel);

  final _FakeClient _client;
  final String channel;

  final _subscribing = StreamController<centrifuge.SubscribingEvent>.broadcast();
  final _subscribed = StreamController<centrifuge.SubscribedEvent>.broadcast();
  final _unsubscribed = StreamController<centrifuge.UnsubscribedEvent>.broadcast();
  final _publication = StreamController<centrifuge.PublicationEvent>.broadcast();
  final _join = StreamController<centrifuge.JoinEvent>.broadcast();
  final _leave = StreamController<centrifuge.LeaveEvent>.broadcast();
  final _error = StreamController<centrifuge.SubscriptionErrorEvent>.broadcast();

  @override
  Stream<centrifuge.SubscribingEvent> get subscribing => _subscribing.stream;
  @override
  Stream<centrifuge.SubscribedEvent> get subscribed => _subscribed.stream;
  @override
  Stream<centrifuge.UnsubscribedEvent> get unsubscribed => _unsubscribed.stream;
  @override
  Stream<centrifuge.PublicationEvent> get publication => _publication.stream;
  @override
  Stream<centrifuge.JoinEvent> get join => _join.stream;
  @override
  Stream<centrifuge.LeaveEvent> get leave => _leave.stream;
  @override
  Stream<centrifuge.SubscriptionErrorEvent> get error => _error.stream;

  @override
  Future<void> subscribe() async {
    if (_client.rejectChannels.contains(channel)) {
      // Centrifuge reports a rejected subscribe on the error stream; it does
      // not throw out of subscribe().
      _error.add(centrifuge.SubscriptionErrorEvent(Exception('rejected')));
      return;
    }
    _subscribed.add(
        centrifuge.SubscribedEvent(false, false, const <int>[], null, false, false));
  }

  @override
  Future<centrifuge.PresenceResult> presence() async =>
      centrifuge.PresenceResult(const {});

  @override
  Future<void> unsubscribe() async {
    if (_client.unsubscribeDelay > Duration.zero) {
      await Future<void>.delayed(_client.unsubscribeDelay);
    }
    _unsubscribed.add(centrifuge.UnsubscribedEvent(0, 'ok'));
  }

  @override
  noSuchMethod(Invocation invocation) => _unsupported(invocation);
}

Never _unsupported(Invocation i) =>
    throw UnsupportedError('not needed by these tests: ${i.memberName}');

void main() {
  late _FakeClient fake;
  late RealtimeService service;

  Future<void> boot() async {
    fake = _FakeClient();
    service = RealtimeService(
      const RiviumChatConfig(apiKey: 'k', userId: 'u'),
      () async => 'token',
      clientFactory: (_, __) => fake,
    );
    await service.connect();
  }

  setUp(boot);

  test('rapid unsubscribe -> subscribe on the same room does not throw', () async {
    await service.subscribeRoom('r1');
    expect(service.isRoomSubscribed('r1'), isTrue);

    // The host's lifecycle pattern: leave on background, rejoin on
    // foreground, without awaiting in between.
    final leaving = service.unsubscribeRoom('r1');
    final rejoining = service.subscribeRoom('r1');

    await expectLater(Future.wait([leaving, rejoining]), completes);
    expect(service.isRoomSubscribed('r1'), isTrue);
  });

  test('survives a slow unsubscribe, as when iOS suspends the socket', () async {
    await service.subscribeRoom('r1');
    fake.unsubscribeDelay = const Duration(milliseconds: 200);

    final leaving = service.unsubscribeRoom('r1');
    final rejoining = service.subscribeRoom('r1');

    await expectLater(Future.wait([leaving, rejoining]), completes);
    expect(service.isRoomSubscribed('r1'), isTrue);
  });

  test('repeated leave/rejoin cycles stay subscribed', () async {
    for (var i = 0; i < 10; i++) {
      unawaited(service.unsubscribeRoom('r1'));
      await service.subscribeRoom('r1');
    }
    expect(service.isRoomSubscribed('r1'), isTrue);
  });

  test('a rejected channel is reported, not silently swallowed', () async {
    fake.rejectChannels.add('typing:room_r1');

    await expectLater(service.subscribeRoom('r1'), throwsA(isA<StateError>()));

    // The channels that did succeed are kept.
    expect(service.subscribedChannelsFor('r1'),
        containsAll(<String>{'chat:room_r1', 'presence:room_r1'}));
    expect(service.isRoomSubscribed('r1'), isFalse);
  });

  test('a failed channel can be retried instead of being stuck', () async {
    fake.rejectChannels.add('typing:room_r1');
    await expectLater(service.subscribeRoom('r1'), throwsA(isA<StateError>()));

    // Server recovers.
    fake.rejectChannels.clear();
    await service.subscribeRoom('r1');
    expect(service.isRoomSubscribed('r1'), isTrue);
  });

  test('disconnect frees channels so reconnecting can resubscribe', () async {
    await service.subscribeRoom('r1');
    await service.disconnect();
    expect(fake.registry, isEmpty,
        reason: 'disconnect must clear the client registry, not just our map');

    await service.connect();
    await expectLater(service.subscribeRoom('r1'), completes);
  });
}
