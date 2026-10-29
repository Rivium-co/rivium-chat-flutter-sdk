import 'dart:async';

import 'package:centrifuge/centrifuge.dart' as centrifuge;
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat/src/services/realtime_service.dart';

/// A stand-in for the realtime client that keeps the one rule that matters
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

  /// Channels the server refuses for good (code, reason), as a real server does
  /// for a user who is not a participant of the room.
  final Map<String, (int, String)> refuseChannels = {};

  int connectCalls = 0;

  int newSubscriptionCalls = 0;

  /// The socket closes while the unsubscribe is in flight: the realtime client then
  /// fails it with the error *type* `ClientDisconnectedError` (not an
  /// instance), as its transport does on close.
  bool removeFailsDisconnected = false;

  /// Channels published to, in order.
  final List<String> published = [];

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
    if (removeFailsDisconnected) {
      await Future<void>.delayed(Duration.zero);
      throw centrifuge.ClientDisconnectedError;
    }
  }

  @override
  Future<void> connect() async {
    connectCalls++;
  }

  @override
  Future<void> disconnect() async {
    // Like the realtime client: the disconnected event is emitted while disconnect()
    // runs, after any await the caller did before it.
    await Future<void>.delayed(Duration.zero);
    _disconnected.add(centrifuge.DisconnectedEvent(0, 'disconnect called'));
  }

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
    final refusal = _client.refuseChannels[channel];
    if (refusal != null) {
      // Like the realtime client on a permanent subscribe error: the error event,
      // then the subscription ends with the server's code and reason.
      final (code, reason) = refusal;
      _error.add(centrifuge.SubscriptionErrorEvent(centrifuge
          .SubscriptionSubscribeError(centrifuge.Error.custom(code, reason, false))));
      _unsubscribed.add(centrifuge.UnsubscribedEvent(code, reason));
      return;
    }
    if (_client.rejectChannels.contains(channel)) {
      // The realtime client reports a rejected subscribe on the error stream; it does
      // not throw out of subscribe().
      _error.add(centrifuge.SubscriptionErrorEvent(Exception('rejected')));
      return;
    }
    _subscribed.add(
        centrifuge.SubscribedEvent(false, false, const <int>[], null, false, false));
  }

  @override
  Future<centrifuge.PublishResult> publish(List<int> data) async {
    _client.published.add(channel);
    return centrifuge.PublishResult();
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

  test('disconnect while unsubscribes are in flight leaves no uncaught error', () async {
    // dispose() / sign-out with rooms open: every channel's unsubscribe is
    // cut off by the closing socket. flutter_test fails the test on any
    // uncaught async error, which is what an app's crash reporter would get.
    await service.subscribeRoom('r1');
    fake.removeFailsDisconnected = true;
    await service.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fake.registry, isEmpty);
  });

  test('dispose with rooms open leaves no uncaught error', () async {
    // dispose() closes the event streams while the disconnect it started is
    // still running; its late events must be dropped, not thrown.
    await service.subscribeRoom('r1');
    service.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('typing is throttled per room, not across rooms', () async {
    await service.subscribeRoom('r1');
    await service.subscribeRoom('r2');

    await service.publishTyping('r1');
    await service.publishTyping('r2');
    await service.publishTyping('r1'); // within 2 s of the first: dropped

    expect(fake.published, ['typing:room_r1', 'typing:room_r2']);
  });

  test('a room the server refuses is reported with its code and reason', () async {
    fake.refuseChannels['chat:room_r1'] = (403, 'Not a participant in this room');
    final states = <SubscriptionStateEvent>[];
    final recovery = <String>[];
    service.onSubscriptionState.listen(states.add);
    service.onRecoveryFailed.listen(recovery.add);

    await expectLater(service.subscribeRoom('r1'), throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);

    final error = states.firstWhere((e) =>
        e.channel == 'chat:room_r1' && e.status == SubscriptionStatus.error);
    expect(error.code, 403);
    expect(error.reason, 'Not a participant in this room');
    final ended = states.firstWhere((e) =>
        e.channel == 'chat:room_r1' && e.status == SubscriptionStatus.unsubscribed);
    expect(ended.code, 403);
    expect(recovery, ['r1'],
        reason: 'the room cannot be followed: the app must reload or show the refusal');
  });

  test('a channel I unsubscribe myself is not reported as a refusal', () async {
    final recovery = <String>[];
    service.onRecoveryFailed.listen(recovery.add);
    await service.subscribeRoom('r1');
    await service.unsubscribeRoom('r1');
    await Future<void>.delayed(Duration.zero);
    expect(recovery, isEmpty);
  });

  test('a failing connection token sets the error state and reports it', () async {
    final failing = RealtimeService(
      const RiviumChatConfig(apiKey: 'k', userId: 'u'),
      () async => throw Exception('401 unknown key'),
      clientFactory: (_, __) => _FakeClient(),
    );
    final errors = <ConnectionErrorEvent>[];
    final states = <ConnectionState>[];
    failing.onConnectionError.listen(errors.add);
    failing.connectionState.listen(states.add);

    await expectLater(failing.connect(), throwsA(isA<Exception>()));
    await Future<void>.delayed(Duration.zero);

    expect(failing.currentConnectionState, ConnectionState.error);
    expect(states.last, ConnectionState.error);
    expect(errors, hasLength(1));
  });

  test('dispose while the token is still being fetched opens no connection', () async {
    final token = Completer<String>();
    final late = _FakeClient();
    var built = 0;
    final pending = RealtimeService(
      const RiviumChatConfig(apiKey: 'k', userId: 'u'),
      () => token.future,
      clientFactory: (_, __) {
        built++;
        return late;
      },
    );

    final connecting = pending.connect();
    pending.dispose();
    token.complete('token');
    await connecting.catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(built, 0, reason: 'a disposed client must not open a socket');
    expect(late.connectCalls, 0);
  });

  test('disconnect while the token is still being fetched opens no connection', () async {
    final token = Completer<String>();
    var built = 0;
    final pending = RealtimeService(
      const RiviumChatConfig(apiKey: 'k', userId: 'u'),
      () => token.future,
      clientFactory: (_, __) {
        built++;
        return _FakeClient();
      },
    );

    final connecting = pending.connect();
    await pending.disconnect();
    token.complete('token');
    await connecting.catchError((_) {});

    expect(built, 0);
    expect(pending.currentConnectionState, ConnectionState.disconnected);
  });
}
