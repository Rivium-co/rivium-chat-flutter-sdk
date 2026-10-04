import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat/src/services/api_service.dart';
import 'package:rivium_chat/src/services/token_manager.dart';

/// Records every request and answers with an empty list.
class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<dynamic>[]),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const config = RiviumChatConfig(apiKey: 'rv_live_test', userId: 'alice');

  test('riviumChatSdkVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(riviumChatSdkVersion, match!.group(1));
    expect(riviumChatSdkName, 'flutter');
  });

  test('every request sends X-Rivium-SDK, and nothing else about it changes', () async {
    final server = _Recorder();
    await ApiService(config, httpClientAdapter: server).listRooms('alice');

    final request = server.requests.single;
    expect(request.headers['X-Rivium-SDK'], 'flutter/$riviumChatSdkVersion');
    expect(request.headers['x-api-key'], 'rv_live_test');
    expect(request.headers.containsKey('x-user-token'), isFalse);
    expect(request.method, 'GET');
    expect(request.uri.queryParameters, {'userId': 'alice'});
    expect(
      request.headers.keys.map((k) => k.toLowerCase()).toSet(),
      {'x-api-key', 'content-type', 'x-rivium-sdk'},
    );
  });

  test('it is sent together with the user token', () async {
    final server = _Recorder();
    final api = ApiService(config, tokens: TokenManager(() async => 'a.b.c'), httpClientAdapter: server);
    await api.listRooms('alice');

    final request = server.requests.single;
    expect(request.headers['X-Rivium-SDK'], 'flutter/$riviumChatSdkVersion');
    expect(request.headers['x-user-token'], 'a.b.c');
  });
}
