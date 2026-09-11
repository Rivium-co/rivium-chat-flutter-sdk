import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat/src/services/api_service.dart';
import 'package:rivium_chat/src/services/token_manager.dart';

/// Answers requests like the chat server: `valid` is the set of tokens it
/// currently accepts; any other token gets `401 token_expired` unless
/// `rejectCode` says otherwise.
class _FakeServer implements HttpClientAdapter {
  final Set<String> valid = {};
  String rejectCode = 'token_expired';
  final List<String?> seenTokens = [];
  Duration latency = Duration.zero;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await Future<void>.delayed(latency);
    final token = options.headers['x-user-token'] as String?;
    seenTokens.add(token);
    if (token != null && !valid.contains(token)) {
      return _json(401, {'statusCode': 401, 'code': rejectCode, 'message': 'nope'});
    }
    return _json(200, <dynamic>[]);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}

/// A JWT-shaped token expiring at [exp]; only the payload matters to the SDK.
String _jwt(String id, DateTime exp) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'sub': id, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  const config = RiviumChatConfig(apiKey: 'rv_live_test', userId: 'alice');
  final inAnHour = DateTime.now().add(const Duration(hours: 1));

  late _FakeServer server;
  late List<String> issued;
  late List<AuthErrorEvent> authErrors;

  /// Issues t1, t2, ... and makes the server accept only the newest one.
  Future<String> provider() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final token = _jwt('t${issued.length + 1}', inAnHour);
    issued.add(token);
    server.valid
      ..clear()
      ..add(token);
    return token;
  }

  ApiService api({ChatTokenProvider? tokenProvider}) => ApiService(
        config,
        tokens: tokenProvider == null ? null : TokenManager(tokenProvider),
        onAuthError: authErrors.add,
        httpClientAdapter: server,
      );

  setUp(() {
    server = _FakeServer();
    issued = [];
    authErrors = [];
  });

  test('without a tokenProvider no user token is sent (legacy unchanged)', () async {
    await api().listRooms('alice');
    expect(server.seenTokens, [null]);
  });

  test('sends the token and reuses it across requests', () async {
    final a = api(tokenProvider: provider);
    await a.listRooms('alice');
    await a.listRooms('bob');
    await a.listRooms('alice');
    expect(issued, hasLength(1));
    expect(server.seenTokens.every((t) => t == issued.first), isTrue);
  });

  test('expired token: refreshes and retries once — the call succeeds', () async {
    final a = api(tokenProvider: provider);
    await a.listRooms('alice');
    server.valid.clear(); // the server now considers t1 expired

    await a.listRooms('alice');

    expect(issued, hasLength(2));
    expect(server.seenTokens, [issued[0], issued[0], issued[1]]);
    expect(authErrors, isEmpty);
  });

  test('a burst of requests with an expired token triggers ONE refresh', () async {
    final a = api(tokenProvider: provider);
    await a.listRooms('alice');
    server.valid.clear();
    server.latency = const Duration(milliseconds: 5);

    await Future.wait(List.generate(8, (_) => a.listRooms('alice')));

    expect(issued, hasLength(2), reason: 'one refresh shared by all 8 requests');
    expect(authErrors, isEmpty);
  });

  test('token about to expire is refreshed before the request (no 401 at all)', () async {
    var n = 0;
    Future<String> shortLived() async {
      n++;
      final token = _jwt('s$n', n == 1 ? DateTime.now().add(const Duration(seconds: 30)) : inAnHour);
      server.valid.add(token);
      return token;
    }

    final a = api(tokenProvider: shortLived);
    await a.listRooms('alice'); // gets s1, valid for 30 s (< 60 s margin)
    await a.listRooms('alice'); // must fetch s2 up front

    expect(n, 2);
    expect(server.seenTokens.last, contains('.'));
    expect(server.seenTokens.where((t) => !server.valid.contains(t)), isEmpty);
  });

  test('retries only once: still expired after refresh → error + auth event', () async {
    final a = api(tokenProvider: () async {
      final token = _jwt('never-valid-${issued.length}', inAnHour);
      issued.add(token);
      return token; // the server never accepts it
    });

    await expectLater(a.listRooms('alice'), throwsA(isA<DioException>()));
    expect(issued, hasLength(2), reason: 'initial token + exactly one refresh');
    expect(authErrors.single.code, 'token_expired');
  });

  test('revoked token: no retry, auth error for the app to log the user out', () async {
    final a = api(tokenProvider: provider);
    await a.listRooms('alice');
    server
      ..valid.clear()
      ..rejectCode = 'token_revoked';

    await expectLater(a.listRooms('alice'), throwsA(isA<DioException>()));
    expect(issued, hasLength(1), reason: 'revocation is not fixed by refreshing');
    expect(authErrors.single.code, 'token_revoked');
  });

  test('tokenProvider failing surfaces as an auth error, not a hang', () async {
    final a = api(tokenProvider: () async => throw StateError('your server is down'));

    await expectLater(a.listRooms('alice'), throwsA(isA<DioException>()));
    expect(authErrors.single.code, 'token_provider_failed');
  });

  test('TokenManager.expiryOf reads exp and tolerates junk', () {
    final exp = DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000);
    expect(TokenManager.expiryOf(_jwt('x', exp)), exp);
    expect(TokenManager.expiryOf('not-a-jwt'), isNull);
  });
}
