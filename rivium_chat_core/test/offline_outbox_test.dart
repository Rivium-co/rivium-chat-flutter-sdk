import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat/src/outbox/outbox.dart';

/// A fake Chat API: stores messages and, like the real one, answers a repeat
/// of the same clientMessageId (same room and sender) with the first stored
/// message.
class FakeChatApi implements HttpClientAdapter {
  bool online = true;

  /// Store the message, then lose the answer (the app sees a network error).
  bool loseNextAnswer = false;

  /// Answer every send with this status instead.
  int? status;
  final bodies = <Map<String, dynamic>>[];
  final stored = <Map<String, dynamic>>[];

  List<String> get contents => stored.map((m) => m['content'] as String).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!online) throw const SocketException('Failed host lookup');
    final segments = options.uri.pathSegments;
    final roomId = segments[segments.indexOf('rooms') + 1];
    final body = Map<String, dynamic>.from(options.data as Map);
    bodies.add(body);
    if (status != null) return _respond(status!, {'message': 'refused'});

    final cmid = body['clientMessageId'] as String?;
    Map<String, dynamic>? existing;
    if (cmid != null) {
      for (final m in stored) {
        if (m['roomId'] == roomId &&
            m['senderUserId'] == body['senderUserId'] &&
            m['clientMessageId'] == cmid) {
          existing = m;
        }
      }
    }
    var code = 200;
    var message = existing;
    if (message == null) {
      code = 201;
      message = {
        'id': 'm-${stored.length + 1}',
        'roomId': roomId,
        'senderUserId': body['senderUserId'],
        'content': body['content'],
        'type': body['type'] ?? 'text',
        'createdAt': '2026-10-29T10:00:00.000Z',
        if (cmid != null) 'clientMessageId': cmid,
      };
      stored.add(message);
    }
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const SocketException('Connection reset by peer');
    }
    return _respond(code, message);
  }

  ResponseBody _respond(int code, Map<String, dynamic> json) => ResponseBody.fromString(
        jsonEncode(json),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeChatApi api;
  var now = DateTime.utc(2026, 10, 29, 10);

  setUp(() {
    api = FakeChatApi();
    now = DateTime.utc(2026, 10, 29, 10);
  });

  RiviumChatClient client({
    bool queue = true,
    OutboxStore? store,
    ChatTokenProvider? tokenProvider,
  }) =>
      RiviumChatClient(
        RiviumChatConfig(
          apiKey: 'rv_live_demo_app',
          userId: 'user-42',
          queueOfflineMessages: queue,
          outboxStore: store,
          tokenProvider: tokenProvider,
        ),
        httpClientAdapter: api,
        now: () => now,
      );

  test('option off: offline send throws and the body has no clientMessageId', () async {
    final chat = client(queue: false);
    api.online = false;
    await expectLater(
        chat.sendMessage('room-1', content: 'Order #1001 is ready'), throwsA(isA<DioException>()));
    api.online = true;
    final m = await chat.sendMessage('room-1', content: 'Order #1001 is ready');
    expect(m.id, 'm-1');
    expect(api.bodies.single.containsKey('clientMessageId'), isFalse);
    expect(await chat.getPendingMessages(), isEmpty);
    chat.dispose();
  });

  test('option on: an online send carries a UUID v4 clientMessageId', () async {
    final chat = client();
    final m = await chat.sendMessage('room-1', content: 'hello');
    final cmid = api.bodies.single['clientMessageId'] as String;
    expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(cmid),
        isTrue);
    expect(m.clientMessageId, cmid);
    expect(m.isPending, isFalse);
    chat.dispose();
  });

  test('offline send is queued, returned as pending, sent once on reconnect', () async {
    final chat = client();
    final sent = <MessageSentEvent>[];
    chat.onMessageSent.listen(sent.add);
    api.online = false;

    final pending = await chat.sendMessage('room-1', content: 'Order #1001 is ready');
    expect(pending.isPending, isTrue);
    expect(pending.id, 'local_${pending.clientMessageId}');
    expect(pending.senderUserId, 'user-42');
    expect(pending.createdAt, now);
    expect((await chat.getPendingMessages(roomId: 'room-1')).map((m) => m.id), [pending.id]);

    api.online = true;
    await chat.retryPendingMessages();
    await chat.retryPendingMessages(); // a second trigger sends nothing more
    await Future<void>.delayed(Duration.zero);

    expect(api.contents, ['Order #1001 is ready']); // the other user sees it once
    expect(await chat.getPendingMessages(), isEmpty);
    expect(sent, hasLength(1));
    expect(sent.single.localId, pending.id);
    expect(sent.single.clientMessageId, pending.clientMessageId);
    expect(sent.single.message.id, 'm-1');
    expect(sent.single.message.clientMessageId, pending.clientMessageId);
    chat.dispose();
  });

  test('a send whose answer was lost is stored once', () async {
    final chat = client();
    api.loseNextAnswer = true;
    final pending = await chat.sendMessage('room-1', content: 'hello');
    expect(pending.isPending, isTrue);
    await chat.retryPendingMessages();

    expect(api.stored, hasLength(1));
    expect(api.bodies, hasLength(2));
    expect(api.bodies[0]['clientMessageId'], api.bodies[1]['clientMessageId']);
    chat.dispose();
  });

  test('order is kept across several queued messages and rooms', () async {
    final chat = client();
    api.online = false;
    await chat.sendMessage('room-1', content: 'a1');
    await chat.sendMessage('room-2', content: 'b1');
    await chat.sendMessage('room-1', content: 'a2');
    api.online = true;
    // Online again, but room-1 still has older messages: this one waits behind them.
    final behind = await chat.sendMessage('room-1', content: 'a3');
    expect(behind.isPending, isTrue);

    await chat.retryPendingMessages();

    expect(api.contents, ['a1', 'b1', 'a2', 'a3']);
    chat.dispose();
  });

  test('permanent errors are not queued and throw as before', () async {
    final chat = client();
    for (final code in [400, 401, 403, 404, 413]) {
      api.status = code;
      await expectLater(
        chat.sendMessage('room-1', content: 'hello'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', code)),
      );
    }
    expect(await chat.getPendingMessages(), isEmpty);
    chat.dispose();
  });

  test('5xx, 408 and 429 are queued', () async {
    final chat = client();
    api.status = 503;
    expect((await chat.sendMessage('room-1', content: 'a')).isPending, isTrue);
    api.status = 429;
    expect((await chat.sendMessage('room-2', content: 'b')).isPending, isTrue);
    api.status = 408;
    expect((await chat.sendMessage('room-3', content: 'c')).isPending, isTrue);
    expect(await chat.getPendingMessages(), hasLength(3));
    chat.dispose();
  });

  test('a failing tokenProvider is transient: the message is queued', () async {
    var fail = true;
    final chat = client(tokenProvider: () async {
      if (fail) throw StateError('token server unreachable');
      return 'token';
    });
    final pending = await chat.sendMessage('room-1', content: 'hello');
    expect(pending.isPending, isTrue);
    expect(api.bodies, isEmpty);
    fail = false;
    await chat.retryPendingMessages();
    expect(api.contents, ['hello']);
    chat.dispose();
  });

  test('a queued message the server then refuses fails with reason rejected', () async {
    final chat = client();
    final failed = <MessageFailedEvent>[];
    chat.onMessageFailed.listen(failed.add);
    api.online = false;
    final pending = await chat.sendMessage('room-1', content: 'hello');
    api.online = true;
    api.status = 403;
    await chat.retryPendingMessages();
    await Future<void>.delayed(Duration.zero);

    expect(failed.single.localId, pending.id);
    expect(failed.single.roomId, 'room-1');
    expect(failed.single.reason, 'rejected');
    expect(await chat.getPendingMessages(), isEmpty);
    chat.dispose();
  });

  test('expired message fails with reason expired, cancel removes one', () async {
    final chat = client();
    final sent = <MessageSentEvent>[];
    final failed = <MessageFailedEvent>[];
    chat.onMessageSent.listen(sent.add);
    chat.onMessageFailed.listen(failed.add);
    api.online = false;
    final old = await chat.sendMessage('room-1', content: 'old');
    final other = await chat.sendMessage('room-2', content: 'cancel me');
    now = now.add(const Duration(hours: 24, seconds: 1));

    expect(await chat.cancelPendingMessage(other.id), isTrue);
    expect(await chat.cancelPendingMessage(other.id), isFalse);
    api.online = true;
    await chat.retryPendingMessages();
    await Future<void>.delayed(Duration.zero);

    expect(failed.single.localId, old.id);
    expect(failed.single.reason, MessageFailedEvent.reasonExpired);
    expect(api.stored, isEmpty);
    expect(sent, isEmpty); // cancel emits nothing
    chat.dispose();
  });

  test('the store keeps the queue for the next client, clearPendingMessages empties it',
      () async {
    final store = _JsonStore();
    final first = client(store: store);
    api.online = false;
    final pending = await first.sendMessage('room-1',
        content: 'survives a restart', metadata: {'orderId': '1001', 'count': 2});
    await Future<void>.delayed(Duration.zero);
    first.dispose();
    expect(store.text, contains('survives a restart'));

    api.online = true;
    final second = client(store: store);
    final restored = await second.getPendingMessages();
    expect(restored.map((m) => m.id), [pending.id]);
    expect(restored.single.createdAt, now);
    await second.retryPendingMessages();
    expect(api.contents, ['survives a restart']);
    expect(api.bodies.last['clientMessageId'], pending.clientMessageId);
    expect(api.bodies.last['metadata'], {'orderId': '1001', 'count': 2});

    api.online = false;
    await second.sendMessage('room-1', content: 'x');
    await second.clearPendingMessages();
    expect(await store.load(), isEmpty);
    expect(await second.getPendingMessages(), isEmpty);
    second.dispose();
  });

  test('stored items of another sender are dropped, never sent', () async {
    final store = MemoryOutboxStore();
    await store.save([
      PendingMessage(
          clientMessageId: 'x', roomId: 'room-1', senderUserId: 'user-7',
          content: 'from another user', createdAt: now),
      PendingMessage(
          clientMessageId: 'y', roomId: 'room-1', senderUserId: 'user-42',
          content: 'mine', createdAt: now),
    ]);
    final chat = client(store: store);
    expect((await chat.getPendingMessages()).map((m) => m.id), ['local_y']);
    await chat.retryPendingMessages();
    expect(api.contents, ['mine']);
    chat.dispose();
  });

  test('racing reconnect triggers send each message once', () async {
    final chat = client();
    api.online = false;
    for (var i = 0; i < 5; i++) {
      await chat.sendMessage('room-1', content: 'm$i');
    }
    api.online = true;
    await Future.wait(List.generate(8, (_) => chat.retryPendingMessages()));
    expect(api.contents, ['m0', 'm1', 'm2', 'm3', 'm4']);
    expect(api.bodies, hasLength(5)); // offline tries never reach the server
    chat.dispose();
  });

  group('timing (virtual time)', () {
    late bool online;
    late List<(Duration, String)> attempts;
    late List<MessageSentEvent> sent;
    late List<MessageFailedEvent> failed;
    final start = DateTime.utc(2026, 10, 29, 10);

    Outbox outbox(FakeAsync async, {Duration requestTime = const Duration(milliseconds: 100)}) =>
        Outbox(
          store: MemoryOutboxStore(),
          userId: 'user-42',
          sender: (p) async {
            attempts.add((async.elapsed, p.content));
            await Future<void>.delayed(requestTime);
            if (!online) throw const SocketException('no network');
            return Message(
                id: 'm-${attempts.length}', roomId: p.roomId, senderUserId: p.senderUserId,
                content: p.content, createdAt: start, clientMessageId: p.clientMessageId);
          },
          onSent: (e) => sent.add(e),
          onFailed: (e) => failed.add(e),
          now: () => start.add(async.elapsed),
        );

    PendingMessage item(FakeAsync async, String content, {String room = 'room-1'}) =>
        PendingMessage(
            clientMessageId: content, roomId: room, senderUserId: 'user-42',
            content: content, createdAt: start.add(async.elapsed));

    setUp(() {
      online = false;
      attempts = [];
      sent = [];
      failed = [];
    });

    test('back-off doubles from 2 s to at most 60 s', () {
      fakeAsync((async) {
        final box = outbox(async);
        box.send(item(async, 'a'));
        async.elapse(const Duration(minutes: 5));
        final starts = attempts.map((a) => a.$1).toList();
        final gaps = [
          for (var i = 1; i < starts.length; i++)
            starts[i] - starts[i - 1] - const Duration(milliseconds: 100)
        ];
        expect(gaps.take(7).map((d) => d.inSeconds),
            [2, 4, 8, 16, 32, 60, 60]);
        box.dispose();
      });
    });

    test('back-off resets after a success; a connect sends at once', () {
      fakeAsync((async) {
        final box = outbox(async);
        box.send(item(async, 'a'));
        async.elapse(const Duration(milliseconds: 100 + 2000 + 100 + 4000 + 100 + 100)); // three failed tries
        expect(box.currentBackoff, const Duration(seconds: 8));
        online = true;
        final before = attempts.length;
        box.onConnected();
        async.elapse(const Duration(milliseconds: 101));
        expect(attempts.length, before + 1);
        expect(sent.map((e) => e.message.content), ['a']);
        expect(box.currentBackoff, Duration.zero);
        async.elapse(const Duration(minutes: 2));
        expect(attempts.length, before + 1); // the old timer finds nothing left
        box.dispose();
      });
    });

    test('racing connect events never send a message twice', () {
      fakeAsync((async) {
        final box = outbox(async);
        box.send(item(async, 'a'));
        async.elapse(const Duration(milliseconds: 150));
        box.send(item(async, 'b'));
        online = true;
        for (var i = 0; i < 5; i++) {
          box.onConnected();
        }
        async.elapse(const Duration(seconds: 2));
        expect(sent.map((e) => e.message.content), ['a', 'b']);
        // a failed once (offline), b queued behind it; then one try each
        expect(attempts.map((a) => a.$2), ['a', 'a', 'b']);
        box.dispose();
      });
    });

    test('cancel during an in-flight send cannot recall it and emits no messageSent', () {
      fakeAsync((async) {
        final box = outbox(async);
        box.send(item(async, 'a'));
        async.elapse(const Duration(milliseconds: 150));
        online = true;
        box.onConnected();
        async.elapse(const Duration(milliseconds: 10)); // the resend is in flight
        late bool cancelled;
        box.cancel('local_a').then((v) => cancelled = v);
        async.elapse(const Duration(seconds: 1));
        expect(cancelled, isTrue);
        expect(attempts.map((a) => a.$2), ['a', 'a']);
        expect(sent, isEmpty);
        box.dispose();
      });
    });

    test('a message older than 24 hours is dropped as expired, not sent', () {
      fakeAsync((async) {
        final box = outbox(async);
        box.send(item(async, 'old'));
        async.elapse(const Duration(milliseconds: 150));
        box.dispose(); // stop its back-off timer; check expiry with a fresh outbox
      });
      fakeAsync((async) {
        final store = MemoryOutboxStore();
        store.save([
          PendingMessage(
              clientMessageId: 'old', roomId: 'room-1', senderUserId: 'user-42',
              content: 'old', createdAt: start.subtract(const Duration(hours: 24, seconds: 1))),
        ]);
        online = true;
        attempts.clear();
        final box = Outbox(
          store: store,
          userId: 'user-42',
          sender: (p) async {
            attempts.add((async.elapsed, p.content));
            return Message(id: 'm-1', roomId: p.roomId, senderUserId: p.senderUserId,
                content: p.content, createdAt: start);
          },
          onSent: (e) => sent.add(e),
          onFailed: (e) => failed.add(e),
          now: () => start,
        );
        box.flush();
        async.flushMicrotasks();
        expect(attempts, isEmpty);
        expect(failed.single.reason, 'expired');
        box.dispose();
      });
    });
  });
}

/// A store that keeps JSON text, like an app's shared_preferences store would.
class _JsonStore implements OutboxStore {
  String text = '[]';

  @override
  Future<List<PendingMessage>> load() async => (jsonDecode(text) as List)
      .map((e) => PendingMessage.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  @override
  Future<void> save(List<PendingMessage> items) async {
    text = jsonEncode(items.map((p) => p.toJson()).toList());
  }
}
