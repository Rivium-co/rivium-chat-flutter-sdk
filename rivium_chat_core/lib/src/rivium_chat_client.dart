import 'dart:async';
import 'package:dio/dio.dart' show HttpClientAdapter;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';
import 'config.dart';
import 'models/models.dart';
import 'events/events.dart';
import 'services/api_service.dart';
import 'services/realtime_service.dart';
import 'services/token_manager.dart';
import 'outbox/outbox.dart';
import 'outbox/outbox_store.dart';
import 'outbox/pending_message.dart';

/// Main client for the RiviumChat SDK.
///
/// This is a headless client that provides all chat functionality
/// without any state management opinions. Use with your preferred
/// state management solution (BLoC, Provider, Riverpod, GetX, etc.).
///
/// Example:
/// ```dart
/// final client = RiviumChatClient(config);
/// await client.connect();
///
/// // Listen to events
/// client.onMessage.listen((message) => print(message));
///
/// // Send a message
/// await client.sendMessage(roomId, content: 'Hello!');
/// ```
class RiviumChatClient {
  final RiviumChatConfig config;
  late final ApiService _api;
  late final RealtimeService _realtime;

  bool _isDisposed = false;

  final _authErrors = StreamController<AuthErrorEvent>.broadcast();
  TokenManager? _tokens;

  final _messageSent = StreamController<MessageSentEvent>.broadcast();
  final _messageFailed = StreamController<MessageFailedEvent>.broadcast();
  Outbox? _outbox;
  StreamSubscription<ConnectionState>? _connectionSub;
  late final DateTime Function() _now;

  /// `httpClientAdapter` and `now` let tests answer requests without a
  /// network and control the outbox's clock.
  RiviumChatClient(
    this.config, {
    @visibleForTesting HttpClientAdapter? httpClientAdapter,
    @visibleForTesting DateTime Function()? now,
  }) {
    _now = now ?? DateTime.now;
    final provider = config.tokenProvider;
    final tokens = provider == null ? null : TokenManager(provider);
    _tokens = tokens;
    _api = ApiService(config,
        tokens: tokens,
        onAuthError: _emitAuthError,
        httpClientAdapter: httpClientAdapter);
    _realtime = RealtimeService(
      config,
      // With a tokenProvider the same user token authenticates REST and the
      // realtime connection; the realtime client asks again before it expires.
      tokens != null
          ? () => _realtimeToken(tokens)
          : () => _api.getRealtimeToken(config.userId, info: config.userInfo),
    );
    if (config.queueOfflineMessages) {
      final outbox = Outbox(
        store: config.outboxStore ?? MemoryOutboxStore(),
        userId: config.userId,
        sender: (p) => _api.sendMessage(
          p.roomId,
          senderUserId: p.senderUserId,
          content: p.content,
          type: p.type,
          attachments: p.attachments,
          metadata: p.metadata,
          replyToId: p.replyToId,
          clientMessageId: p.clientMessageId,
        ),
        onSent: (e) {
          if (!_messageSent.isClosed) _messageSent.add(e);
        },
        onFailed: (e) {
          if (!_messageFailed.isClosed) _messageFailed.add(e);
        },
        now: _now,
      );
      _outbox = outbox;
      _connectionSub = _realtime.connectionState.listen((state) {
        if (state == ConnectionState.connected) outbox.onConnected();
      });
    }
  }

  /// A message queued while offline was stored by the server. Only with
  /// [RiviumChatConfig.queueOfflineMessages].
  Stream<MessageSentEvent> get onMessageSent => _messageSent.stream;

  /// A message queued while offline left the queue without being stored
  /// (`reason` 'expired' or 'rejected'). Only with
  /// [RiviumChatConfig.queueOfflineMessages].
  Stream<MessageFailedEvent> get onMessageFailed => _messageFailed.stream;

  /// The user token for the realtime connection. A failing tokenProvider is
  /// reported on [onAuthError] like it is for REST calls.
  Future<String> _realtimeToken(TokenManager tokens) async {
    try {
      return await tokens.get();
    } catch (e) {
      _emitAuthError(AuthErrorEvent(
        code: 'token_provider_failed',
        message: 'tokenProvider failed',
        error: e,
      ));
      rethrow;
    }
  }

  void _emitAuthError(AuthErrorEvent event) {
    if (!_authErrors.isClosed) _authErrors.add(event);
  }

  /// Identity errors a token refresh cannot fix (revoked or invalid token,
  /// project requires a token, tokenProvider failing). Send the user to
  /// login. Only emitted when [RiviumChatConfig.tokenProvider] is set.
  Stream<AuthErrorEvent> get onAuthError => _authErrors.stream;

  // ============ Connection ============

  /// Current connection state.
  ConnectionState get connectionState => _realtime.currentConnectionState;

  /// Stream of connection state changes.
  Stream<ConnectionState> get onConnectionStateChange =>
      _realtime.connectionState;

  /// Connects to the realtime server.
  ///
  /// Throws an [ArgumentError] when [RiviumChatConfig.apiKey] or
  /// [RiviumChatConfig.userId] is empty (checked here, not when the client is
  /// created, so a widget tree built before the user is known never breaks).
  Future<void> connect() async {
    _checkDisposed();
    config.validate();
    await _realtime.connect();
  }

  /// Disconnects from the realtime server.
  Future<void> disconnect() async {
    _checkDisposed();
    await _realtime.disconnect();
  }

  /// Whether the client is connected.
  bool get isConnected =>
      _realtime.currentConnectionState == ConnectionState.connected;

  // ============ Event Streams ============

  /// Stream of incoming messages.
  Stream<Message> get onMessage => _realtime.onMessage;

  /// Stream of read receipts.
  Stream<ReadReceipt> get onReadReceipt => _realtime.onReadReceipt;

  /// Stream of message deletions.
  Stream<MessageDeletion> get onMessageDeleted => _realtime.onMessageDeleted;

  /// Stream of typing events.
  Stream<TypingEvent> get onTypingEvent => _realtime.onTypingEvent;

  /// Stream of presence changes.
  Stream<PresenceEvent> get onPresenceChange => _realtime.onPresenceChange;

  /// Stream of reaction events.
  Stream<ReactionEvent> get onReactionEvent => _realtime.onReactionEvent;

  /// Stream of message edits.
  Stream<MessageEditEvent> get onMessageEdited => _realtime.onMessageEdited;

  /// Stream of pin/unpin events.
  Stream<MessagePinEvent> get onMessagePinChanged =>
      _realtime.onMessagePinChanged;

  /// Stream of connection errors.
  Stream<ConnectionErrorEvent> get onConnectionError =>
      _realtime.onConnectionError;

  /// Stream of subscription state changes.
  Stream<SubscriptionStateEvent> get onSubscriptionState =>
      _realtime.onSubscriptionState;

  /// Stream of recovery failures (room IDs that need full message refresh).
  Stream<String> get onRecoveryFailed => _realtime.onRecoveryFailed;

  /// Stream of realtime frames the SDK couldn't decode or dispatch. Wire
  /// this to your observability layer to catch server↔client schema
  /// drift instead of silently dropping messages (which is what happened
  /// prior to 0.1.1).
  Stream<RealtimeParseError> get onParseError => _realtime.onParseError;

  // ============ Room Subscriptions ============

  /// Subscribes to realtime events for a room.
  Future<void> subscribeRoom(String roomId) async {
    _checkDisposed();
    await _realtime.subscribeRoom(roomId);
  }

  /// Subscribes only to a room's chat channel for messages/read receipts, without joining presence or typing.
  Future<void> observeRoom(String roomId) async {
    _checkDisposed();
    await _realtime.observeRoom(roomId);
  }

  /// Unsubscribes from a room's realtime events.
  Future<void> unsubscribeRoom(String roomId) async {
    _checkDisposed();
    await _realtime.unsubscribeRoom(roomId);
  }

  /// Leaves presence and typing channels but keeps chat channel for unread updates.
  Future<void> leaveRoom(String roomId) async {
    _checkDisposed();
    await _realtime.leaveRoom(roomId);
  }

  /// Gets currently online users in a room via the server API.
  Future<Set<String>> getRoomPresence(String roomId) async {
    _checkDisposed();
    return _api.getRoomPresence(roomId);
  }

  /// Publishes a typing indicator.
  Future<void> publishTyping(String roomId) async {
    _checkDisposed();
    await _realtime.publishTyping(roomId);
  }

  // ============ Room Operations ============

  /// Creates a new chat room.
  Future<Room> createRoom({
    RoomType type = RoomType.direct,
    String? name,
    required List<Map<String, dynamic>> participants,
    Map<String, dynamic>? metadata,
  }) async {
    _checkDisposed();
    return _api.createRoom(
      type: type,
      name: name,
      participants: participants,
      metadata: metadata,
    );
  }

  /// Finds an existing room by external ID or creates a new one.
  Future<Room> findOrCreateRoom({
    required String externalId,
    RoomType type = RoomType.direct,
    String? name,
    required List<Map<String, dynamic>> participants,
    Map<String, dynamic>? metadata,
  }) async {
    _checkDisposed();
    return _api.findOrCreateRoom(
      externalId: externalId,
      type: type,
      name: name,
      participants: participants,
      metadata: metadata,
    );
  }

  /// Gets a room by its external ID.
  Future<Room> getRoomByExternalId(String externalId) async {
    _checkDisposed();
    return _api.getRoomByExternalId(externalId);
  }

  /// Lists all rooms for the current user.
  Future<List<Room>> listRooms() async {
    _checkDisposed();
    return _api.listRooms(config.userId);
  }

  /// Gets a room by ID.
  Future<Room> getRoom(String roomId) async {
    _checkDisposed();
    return _api.getRoom(roomId);
  }

  /// Adds a participant to a room.
  Future<Participant> addParticipant(
    String roomId, {
    required String externalUserId,
    String? displayName,
    String? locale,
    ParticipantRole role = ParticipantRole.member,
  }) async {
    _checkDisposed();
    return _api.addParticipant(
      roomId,
      externalUserId: externalUserId,
      displayName: displayName,
      locale: locale,
      role: role,
    );
  }

  // ============ Message Operations ============

  /// Sends a message to a room.
  ///
  /// With [RiviumChatConfig.queueOfflineMessages] on, a send that fails
  /// because of the network is queued and returned as a pending message
  /// (`isPending == true`, id `local_<clientMessageId>`) instead of
  /// throwing; it is sent when the connection is back. Errors the server
  /// answers (not a member, invalid message, plan limit) still throw.
  Future<Message> sendMessage(
    String roomId, {
    required String content,
    MessageType type = MessageType.text,
    List<Attachment>? attachments,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    _checkDisposed();
    final outbox = _outbox;
    if (outbox != null) {
      return outbox.send(PendingMessage(
        clientMessageId: const Uuid().v4(),
        roomId: roomId,
        senderUserId: config.userId,
        content: content,
        type: type,
        attachments: attachments,
        metadata: metadata,
        replyToId: replyToId,
        createdAt: _now(),
      ));
    }
    return _api.sendMessage(
      roomId,
      senderUserId: config.userId,
      content: content,
      type: type,
      attachments: attachments,
      metadata: metadata,
      replyToId: replyToId,
    );
  }

  // ============ Offline outbox (queueOfflineMessages) ============

  /// Messages waiting to be sent, oldest first, as pending messages
  /// (`isPending == true`). Only [roomId]'s when given. Empty when
  /// [RiviumChatConfig.queueOfflineMessages] is off.
  Future<List<Message>> getPendingMessages({String? roomId}) async {
    final outbox = _outbox;
    if (outbox == null) return const [];
    return (await outbox.pending(roomId: roomId)).map((p) => p.toMessage()).toList();
  }

  /// Tries to send the waiting messages now; completes when done or stopped
  /// by the network.
  Future<void> retryPendingMessages() async {
    if (_isDisposed) return;
    await _outbox?.flush();
  }

  /// Removes a waiting message ([localId] = the pending message's id) from
  /// the queue. Emits nothing. Returns false when it is not queued (any
  /// more); a message already being sent cannot be recalled.
  Future<bool> cancelPendingMessage(String localId) async =>
      await _outbox?.cancel(localId) ?? false;

  /// Empties the queue, including a persistent store. Call it on sign-out
  /// when another user may sign in on this device.
  Future<void> clearPendingMessages() async => _outbox?.clear();

  /// Gets messages for a room with pagination.
  Future<PaginatedMessages> getMessages(
    String roomId, {
    int limit = 50,
    String? before,
  }) async {
    _checkDisposed();
    return _api.getMessages(
      roomId,
      userId: config.userId,
      limit: limit,
      before: before,
    );
  }

  /// Marks messages in a room as read.
  Future<void> markAsRead(String roomId) async {
    _checkDisposed();
    await _api.markAsRead(roomId, config.userId);
  }

  /// Deletes a message.
  Future<void> deleteMessage(String messageId) async {
    _checkDisposed();
    await _api.deleteMessage(messageId, config.userId);
  }

  /// Edits a message.
  Future<Message> editMessage(String messageId, {required String content}) async {
    _checkDisposed();
    return _api.editMessage(
      messageId,
      userId: config.userId,
      content: content,
    );
  }

  /// Searches messages in a room.
  Future<List<Message>> searchMessages(
    String roomId, {
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    _checkDisposed();
    return _api.searchMessages(
      roomId,
      userId: config.userId,
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  /// Searches messages in a room and reports how many match in total.
  ///
  /// Same search as [searchMessages]; the result also carries `total` (all
  /// matches, not only this page) and `hasMore`.
  ///
  /// ```dart
  /// final result = await client.searchMessagesWithTotal(roomId, query: 'Order #1001');
  /// print('${result.total} matches');
  /// ```
  Future<SearchResult> searchMessagesWithTotal(
    String roomId, {
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    _checkDisposed();
    return _api.searchMessagesWithTotal(
      roomId,
      userId: config.userId,
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  // ============ Reaction Operations ============

  /// Adds a reaction to a message.
  Future<Reaction> addReaction(String messageId, {required String emoji}) async {
    _checkDisposed();
    return _api.addReaction(
      messageId,
      userId: config.userId,
      emoji: emoji,
    );
  }

  /// Removes a reaction from a message.
  Future<void> removeReaction(String messageId, {required String emoji}) async {
    _checkDisposed();
    await _api.removeReaction(
      messageId,
      userId: config.userId,
      emoji: emoji,
    );
  }

  /// Gets all reactions for a message.
  Future<List<Reaction>> getReactions(String messageId) async {
    _checkDisposed();
    return _api.getReactions(messageId);
  }

  // ============ Pin Operations ============

  /// Pins a message.
  Future<Message> pinMessage(String messageId) async {
    _checkDisposed();
    return _api.pinMessage(messageId, userId: config.userId);
  }

  /// Unpins a message.
  Future<void> unpinMessage(String messageId) async {
    _checkDisposed();
    await _api.unpinMessage(messageId, userId: config.userId);
  }

  /// Gets all pinned messages in a room.
  Future<List<Message>> getPinnedMessages(String roomId) async {
    _checkDisposed();
    return _api.getPinnedMessages(roomId);
  }

  // ============ Other Operations ============

  /// Gets unread message summary for the current user.
  Future<UnreadSummary> getUnreadSummary() async {
    _checkDisposed();
    return _api.getUnreadSummary(config.userId);
  }

  /// Gets messages where the current user was mentioned.
  Future<List<Message>> getMentions(
    String roomId, {
    int limit = 20,
    int offset = 0,
  }) async {
    _checkDisposed();
    return _api.getMentions(
      roomId,
      userId: config.userId,
      limit: limit,
      offset: offset,
    );
  }

  // ============ Lifecycle ============

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('RiviumChatClient has been disposed');
    }
  }

  /// Disposes all resources.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _connectionSub?.cancel();
    _outbox?.dispose();
    _messageSent.close();
    _messageFailed.close();
    _realtime.dispose();
    _api.dispose();
    _tokens?.clear();
    _authErrors.close();
  }
}
