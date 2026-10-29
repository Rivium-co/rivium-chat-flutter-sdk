import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';

Message _message(String id, {String sender = 'user-7', bool pinned = false}) =>
    Message(
      id: id,
      roomId: 'room-1',
      senderUserId: sender,
      content: 'Order #1001 shipped',
      type: MessageType.text,
      createdAt: DateTime.utc(2026, 10, 1, 10),
      isPinned: pinned,
    );

/// Stands in for the client: answers the calls a chat screen makes.
class _FakeClient implements RiviumChatClient {
  @override
  final RiviumChatConfig config =
      const RiviumChatConfig(apiKey: 'rv_live_test', userId: 'user-42');

  List<Message> history = [_message('m1')];
  Completer<void>? historyGate;
  int historyLoads = 0;
  bool disposed = false;
  bool failPin = false;

  final recoveryFailed = StreamController<String>.broadcast();

  void _check() {
    if (disposed) throw StateError('RiviumChatClient has been disposed');
  }

  @override
  Future<void> subscribeRoom(String roomId) async => _check();

  @override
  Future<void> leaveRoom(String roomId) async => _check();

  @override
  Future<PaginatedMessages> getMessages(String roomId,
      {int limit = 50, String? before}) async {
    _check();
    historyLoads++;
    await historyGate?.future;
    return PaginatedMessages(messages: history, hasMore: false);
  }

  @override
  Future<Set<String>> getRoomPresence(String roomId) async => {};

  @override
  Future<Room> getRoom(String roomId) async => throw StateError('not needed');

  @override
  Future<void> markAsRead(String roomId) async {}

  @override
  Future<Message> pinMessage(String messageId) async {
    _check();
    if (failPin) throw StateError('403');
    return _message(messageId, pinned: true);
  }

  @override
  Future<void> unpinMessage(String messageId) async => _check();

  @override
  Stream<String> get onRecoveryFailed => recoveryFailed.stream;
  @override
  Stream<Message> get onMessage => const Stream.empty();
  @override
  Stream<MessageDeletion> get onMessageDeleted => const Stream.empty();
  @override
  Stream<MessageEditEvent> get onMessageEdited => const Stream.empty();
  @override
  Stream<ReactionEvent> get onReactionEvent => const Stream.empty();
  @override
  Stream<MessagePinEvent> get onMessagePinChanged => const Stream.empty();
  @override
  Stream<ReadReceipt> get onReadReceipt => const Stream.empty();
  @override
  Stream<PresenceEvent> get onPresenceChange => const Stream.empty();
  @override
  Stream<TypingEvent> get onTypingEvent => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not needed: ${invocation.memberName}');
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('Pin shows the message as pinned once the server confirms', () async {
    final client = _FakeClient();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();

    await state.pinMessage('m1');

    expect(state.messages.single.isPinned, isTrue);

    await state.unpinMessage('m1');
    expect(state.messages.single.isPinned, isFalse);
    state.dispose();
  });

  test('a refused pin leaves the message unpinned and reports the error', () async {
    final client = _FakeClient()..failPin = true;
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();

    await expectLater(state.pinMessage('m1'), throwsA(isA<StateError>()));
    expect(state.messages.single.isPinned, isFalse);
    state.dispose();
  });

  test('closing the screen while the history loads throws nothing', () async {
    final client = _FakeClient()..historyGate = Completer<void>();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();

    state.dispose();
    client.historyGate!.complete();
    await _settle();
  });

  test('closing the screen after the client was disposed throws nothing', () async {
    final client = _FakeClient();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();

    client.disposed = true;
    state.dispose();
    await _settle();
  });

  test('recoveryFailed reloads the history', () async {
    final client = _FakeClient();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();
    expect(client.historyLoads, 1);

    client.history = [_message('m2'), _message('m1')];
    client.recoveryFailed.add('room-1');
    await _settle();

    expect(client.historyLoads, 2);
    expect(state.messages.map((m) => m.id), ['m1', 'm2']);
    state.dispose();
  });

  test('displayNameFor falls back to the user id', () async {
    final state = ChatChannelState(client: _FakeClient(), roomId: 'room-1');
    await _settle();
    expect(state.displayNameFor('user-7'), 'user-7');
    state.dispose();
  });
}
