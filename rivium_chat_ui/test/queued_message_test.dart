import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';
import 'package:rivium_chat_ui/src/state/queued_message_merge.dart';

Message _queued(String cmid, [String content = 'Order #1001 is ready']) => Message(
      id: 'local_$cmid',
      roomId: 'room-1',
      senderUserId: 'user-42',
      content: content,
      createdAt: DateTime.utc(2026, 10, 29, 10),
      isPending: true,
      clientMessageId: cmid,
    );

Message _stored(String id, String? cmid, [String content = 'Order #1001 is ready']) => Message(
      id: id,
      roomId: 'room-1',
      senderUserId: 'user-42',
      content: content,
      createdAt: DateTime.utc(2026, 10, 29, 10, 0, 1),
      clientMessageId: cmid,
    );

/// A client with `queueOfflineMessages` on whose sends are queued (offline).
class _OfflineClient implements RiviumChatClient {
  @override
  final RiviumChatConfig config = const RiviumChatConfig(
      apiKey: 'rv_live_demo_app', userId: 'user-42', queueOfflineMessages: true);

  final messages = StreamController<Message>.broadcast();
  final sent = StreamController<MessageSentEvent>.broadcast();
  final failed = StreamController<MessageFailedEvent>.broadcast();
  int sends = 0;

  @override
  Future<Message> sendMessage(String roomId,
      {required String content,
      MessageType type = MessageType.text,
      List<Attachment>? attachments,
      Map<String, dynamic>? metadata,
      String? replyToId}) async {
    sends++;
    return _queued('cmid-$sends', content);
  }

  @override
  Future<List<Message>> getPendingMessages({String? roomId}) async => const [];
  @override
  Future<void> subscribeRoom(String roomId) async {}
  @override
  Future<void> leaveRoom(String roomId) async {}
  @override
  Future<PaginatedMessages> getMessages(String roomId, {int limit = 50, String? before}) async =>
      const PaginatedMessages(messages: [], hasMore: false);
  @override
  Future<Set<String>> getRoomPresence(String roomId) async => {};
  @override
  Future<Room> getRoom(String roomId) async => throw StateError('not needed');
  @override
  Future<void> markAsRead(String roomId) async {}

  @override
  Stream<Message> get onMessage => messages.stream;
  @override
  Stream<MessageSentEvent> get onMessageSent => sent.stream;
  @override
  Stream<MessageFailedEvent> get onMessageFailed => failed.stream;
  @override
  Stream<String> get onRecoveryFailed => const Stream.empty();
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
  test('a queued message shows "Waiting for network…", not failed', () {
    expect(isQueuedOffline(_queued('abc')), isTrue);
    expect(_queued('abc').isFailed, isFalse);
    expect(isQueuedOffline(_queued('abc').copyWith(id: 'pending_1')), isFalse);
    expect(waitingForNetworkLabel, 'Waiting for network…');
  });

  test('chat screen: queued, then replaced on messageSent, live event does not duplicate',
      () async {
    final client = _OfflineClient();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();

    await state.sendMessage(content: 'Order #1001 is ready');
    expect(state.messages.map((m) => m.id), ['local_cmid-1']);
    expect(isQueuedOffline(state.messages.single), isTrue);

    client.sent.add(MessageSentEvent(
        localId: 'local_cmid-1', clientMessageId: 'cmid-1', message: _stored('m-1', 'cmid-1')));
    await _settle();
    expect(state.messages.map((m) => m.id), ['m-1']);

    client.messages.add(_stored('m-1', 'cmid-1'));
    await _settle();
    expect(state.messages.map((m) => m.id), ['m-1']);
    state.dispose();
  });

  test('chat screen: live event first, then messageSent: shown once', () async {
    final client = _OfflineClient();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();
    await state.sendMessage(content: 'Order #1001 is ready');

    client.messages.add(_stored('m-1', 'cmid-1'));
    await _settle();
    expect(state.messages.map((m) => m.id), ['m-1']);

    client.sent.add(MessageSentEvent(
        localId: 'local_cmid-1', clientMessageId: 'cmid-1', message: _stored('m-1', 'cmid-1')));
    await _settle();
    expect(state.messages.map((m) => m.id), ['m-1']);
    state.dispose();
  });

  test('chat screen: messageFailed shows the message as failed (Retry)', () async {
    final client = _OfflineClient();
    final state = ChatChannelState(client: client, roomId: 'room-1');
    await _settle();
    await state.sendMessage(content: 'Order #1001 is ready');

    client.failed.add(const MessageFailedEvent(
        localId: 'local_cmid-1', clientMessageId: 'cmid-1', roomId: 'room-1',
        error: 'expired', reason: 'expired'));
    await _settle();
    expect(state.messages.single.isFailed, isTrue);
    expect(state.messages.single.isPending, isFalse);

    await state.retryMessage(state.messages.single);
    expect(client.sends, 2);
    expect(state.messages.map((m) => m.id), ['local_cmid-2']);
    state.dispose();
  });

  test('a queued copy is not taken by another message with the same text', () {
    final list = [_queued('abc', 'ok')];
    mergeLiveMessage(list, _stored('m-5', null, 'ok'));
    expect(list.map((m) => m.id), ['m-5', 'local_abc']);
  });
}
