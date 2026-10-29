import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat/src/services/api_service.dart';

/// Answers every request with [body] and remembers the request it got.
class _FixedServer implements HttpClientAdapter {
  _FixedServer(this.body);

  final Object body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _message(String id, String content) => {
      'id': id,
      'roomId': 'room-1',
      'senderUserId': 'bob',
      'content': content,
      'type': 'text',
      'createdAt': '2026-10-01T10:00:00.000Z',
    };

void main() {
  const config = RiviumChatConfig(apiKey: 'rv_live_test', userId: 'alice');

  ApiService api(_FixedServer server) =>
      ApiService(config, httpClientAdapter: server);

  test('searchMessagesWithTotal reports the total number of matches', () async {
    final server = _FixedServer({
      'messages': [_message('m1', 'hello there'), _message('m2', 'hello again')],
      'total': 5,
    });

    final result = await api(server)
        .searchMessagesWithTotal('room-1', userId: 'alice', query: 'hello', limit: 2);

    expect(result.messages.map((m) => m.id), ['m1', 'm2']);
    expect(result.total, 5);
    expect(result.hasMore, isTrue);
  });

  test('searchMessagesWithTotal: the last page has no more', () async {
    final server = _FixedServer({
      'messages': [_message('m3', 'hello')],
      'total': 3,
    });

    final result = await api(server).searchMessagesWithTotal('room-1',
        userId: 'alice', query: 'hello', limit: 2, offset: 2);

    expect(result.total, 3);
    expect(result.hasMore, isFalse);
  });

  test('searchMessagesWithTotal accepts a bare list (total = its length)', () async {
    final server = _FixedServer([_message('m1', 'hello')]);

    final result = await api(server)
        .searchMessagesWithTotal('room-1', userId: 'alice', query: 'hello');

    expect(result.total, 1);
    expect(result.hasMore, isFalse);
  });

  test('searchMessages reads the { messages, total } answer', () async {
    final server = _FixedServer({
      'messages': [_message('m1', 'hello there'), _message('m2', 'hello again')],
      'total': 2,
    });

    final results =
        await api(server).searchMessages('room-1', userId: 'alice', query: 'hello');

    expect(results.map((m) => m.id), ['m1', 'm2']);
    expect(results.first.content, 'hello there');
  });

  test('getMentions returns the mentioned messages', () async {
    final server = _FixedServer([
      {
        'id': 'mention-1',
        'messageId': 'm1',
        'mentionedUserId': 'alice',
        'roomId': 'room-1',
        'createdAt': '2026-10-01T10:00:01.000Z',
        'message': _message('m1', '@alice look'),
      },
    ]);

    final results = await api(server).getMentions('room-1', userId: 'alice');

    expect(results, hasLength(1));
    expect(results.single.id, 'm1');
    expect(results.single.content, '@alice look');
  });

  test('getRoomByExternalId encodes the external id', () async {
    final server = _FixedServer({
      'id': 'room-1',
      'appId': 'app',
      'type': 'direct',
      'isActive': true,
      'createdAt': '2026-10-01T10:00:00.000Z',
      'updatedAt': '2026-10-01T10:00:00.000Z',
    });

    try {
      await api(server).getRoomByExternalId('order/42 #a');
    } catch (_) {
      // Only the request path matters here.
    }

    expect(server.requests.single.uri.path,
        '/api/v1/rooms/by-external-id/order%2F42%20%23a');
  });

  test('an empty apiKey or userId is rejected by connect(), not by the constructor', () async {
    final noKey = RiviumChatClient(const RiviumChatConfig(apiKey: '', userId: 'alice'));
    await expectLater(noKey.connect(), throwsArgumentError);
    final noUser = RiviumChatClient(const RiviumChatConfig(apiKey: 'rv_live_test', userId: ' '));
    await expectLater(noUser.connect(), throwsArgumentError);
  });

  test('a failing tokenProvider during connect() is reported as token_provider_failed',
      () async {
    final client = RiviumChatClient(RiviumChatConfig(
      apiKey: 'rv_live_test',
      userId: 'alice',
      tokenProvider: () async => throw Exception('your server is down'),
    ));
    final codes = <String>[];
    final sub = client.onAuthError.listen((e) => codes.add(e.code));

    await expectLater(client.connect(), throwsA(isA<Exception>()));
    await Future<void>.delayed(Duration.zero);

    expect(codes, ['token_provider_failed']);
    await sub.cancel();
    client.dispose();
  });
}
