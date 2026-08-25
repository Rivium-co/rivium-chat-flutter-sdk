import 'dart:async';
import 'config.dart';
import 'models/models.dart';
import 'events/events.dart';
import 'services/api_service.dart';
import 'services/realtime_service.dart';

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

  RiviumChatClient(this.config) {
    _api = ApiService(config);
    _realtime = RealtimeService(
      config,
      () => _api.getCentrifugoToken(config.userId, info: config.userInfo),
    );
  }

  // ============ Connection ============

  /// Current connection state.
  ConnectionState get connectionState => _realtime.currentConnectionState;

  /// Stream of connection state changes.
  Stream<ConnectionState> get onConnectionStateChange =>
      _realtime.connectionState;

  /// Connects to the realtime server.
  Future<void> connect() async {
    _checkDisposed();
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
  Future<Message> sendMessage(
    String roomId, {
    required String content,
    MessageType type = MessageType.text,
    List<Attachment>? attachments,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    _checkDisposed();
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
    _realtime.dispose();
    _api.dispose();
  }
}
