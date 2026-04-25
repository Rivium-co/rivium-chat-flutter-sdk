import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'rivium_chat_scope.dart';

/// State for a single chat room/channel.
///
/// Manages messages, presence, typing indicators, and other room-specific state.
class ChatChannelState extends ChangeNotifier {
  final RiviumChatClient client;
  final String roomId;

  List<Message> _messages = [];
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  Set<String> _onlineUsers = {};
  Set<String> _typingUsers = {};
  DateTime? _otherUserLastRead;
  Map<String, String> _participantDisplayNames = {};
  Object? _error;

  final List<StreamSubscription> _subscriptions = [];

  ChatChannelState({
    required this.client,
    required this.roomId,
  }) {
    _init();
  }

  // ============ Getters ============

  List<Message> get messages => List.unmodifiable(_messages);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  Set<String> get onlineUsers => Set.unmodifiable(_onlineUsers);
  Set<String> get typingUsers => Set.unmodifiable(_typingUsers);
  DateTime? get otherUserLastRead => _otherUserLastRead;
  /// Maps externalUserId → displayName from room participants.
  Map<String, String> get participantDisplayNames => Map.unmodifiable(_participantDisplayNames);
  Object? get error => _error;
  bool get hasError => _error != null;

  bool isUserOnline(String userId) => _onlineUsers.contains(userId);
  bool isUserTyping(String userId) => _typingUsers.contains(userId);

  // ============ Initialization ============

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Subscribe to room
      await client.subscribeRoom(roomId);

      // Load initial messages (API returns oldest first, we need newest first for reversed ListView)
      final result = await client.getMessages(roomId);
      _messages = result.messages.reversed.toList();
      _hasMore = result.hasMore;

      // Load initial presence
      _onlineUsers = await client.getRoomPresence(roomId);

      // Load initial read state and display names from room participants
      try {
        final room = await client.getRoom(roomId);
        for (final p in room.participants) {
          if (p.displayName != null) {
            _participantDisplayNames[p.externalUserId] = p.displayName!;
          }
        }
        final otherParticipant = room.participants
            .where((p) => p.externalUserId != client.config.userId)
            .firstOrNull;
        if (otherParticipant?.lastReadAt != null) {
          _otherUserLastRead = otherParticipant!.lastReadAt;
        }
      } catch (_) {
        // Non-critical: read receipts will still work via real-time events
      }

      // Setup listeners
      _setupListeners();

      // Mark messages as read
      _markAsReadSilently();

      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks messages as read silently (no error handling)
  void _markAsReadSilently() {
    client.markAsRead(roomId).catchError((_) {});
  }

  void _setupListeners() {
    // New messages
    _subscriptions.add(client.onMessage
        .where((m) => m.roomId == roomId)
        .listen(_handleNewMessage));

    // Message deleted
    _subscriptions.add(client.onMessageDeleted
        .where((e) => e.roomId == roomId)
        .listen(_handleMessageDeleted));

    // Message edited
    _subscriptions.add(client.onMessageEdited
        .where((e) => e.roomId == roomId)
        .listen(_handleMessageEdited));

    // Reactions
    _subscriptions.add(client.onReactionEvent
        .where((e) => e.roomId == roomId)
        .listen(_handleReactionEvent));

    // Pin changes
    _subscriptions.add(client.onMessagePinChanged
        .where((e) => e.roomId == roomId)
        .listen(_handlePinEvent));

    // Read receipts
    _subscriptions.add(client.onReadReceipt
        .where((e) => e.roomId == roomId && e.userId != client.config.userId)
        .listen(_handleReadReceipt));

    // Presence
    _subscriptions.add(client.onPresenceChange
        .where((e) => e.roomId == roomId)
        .listen(_handlePresenceChange));

    // Typing
    _subscriptions.add(client.onTypingEvent
        .where((e) => e.roomId == roomId && e.userId != client.config.userId)
        .listen(_handleTypingEvent));

    // Recovery failed
    _subscriptions.add(client.onRecoveryFailed
        .where((id) => id == roomId)
        .listen((_) => refresh()));
  }

  // ============ Event Handlers ============

  void _handleNewMessage(Message message) {
    // Check if message already exists (by ID)
    final existingIndex = _messages.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      // Update existing (remove pending flag)
      _messages[existingIndex] = message;
    } else {
      // Check if this is the real version of a pending message (same sender + content)
      final pendingIndex = _messages.indexWhere((m) =>
          m.isPending &&
          m.senderUserId == message.senderUserId &&
          m.content == message.content);
      if (pendingIndex >= 0) {
        _messages[pendingIndex] = message;
      } else {
        // Add new message at the beginning (newest first)
        _messages.insert(0, message);
      }
    }
    notifyListeners();

    // Mark as read if message is from other user
    if (message.senderUserId != client.config.userId) {
      _markAsReadSilently();
    }
  }

  void _handleMessageDeleted(MessageDeletion deletion) {
    final index = _messages.indexWhere((m) => m.id == deletion.messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(isDeleted: true);
      notifyListeners();
    }
  }

  void _handleMessageEdited(MessageEditEvent event) {
    final index = _messages.indexWhere((m) => m.id == event.messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(
        content: event.content,
        isEdited: true,
        editedAt: event.editedAt,
      );
      notifyListeners();
    }
  }

  void _handleReactionEvent(ReactionEvent event) {
    final index = _messages.indexWhere((m) => m.id == event.messageId);
    if (index >= 0) {
      final message = _messages[index];
      List<Reaction> reactions = List.from(message.reactions ?? []);

      if (event.added) {
        // Check if reaction already exists (avoid duplicates)
        final alreadyExists = reactions.any(
          (r) => r.userId == event.userId && r.emoji == event.emoji,
        );
        if (!alreadyExists) {
          reactions.add(Reaction(
            id: event.reactionId ?? '',
            messageId: event.messageId,
            userId: event.userId,
            emoji: event.emoji,
            createdAt: DateTime.now(),
          ));
        }
      } else {
        reactions.removeWhere(
            (r) => r.userId == event.userId && r.emoji == event.emoji);
      }

      _messages[index] = message.copyWith(reactions: reactions);
      notifyListeners();
    }
  }

  void _handlePinEvent(MessagePinEvent event) {
    final index = _messages.indexWhere((m) => m.id == event.messageId);
    if (index >= 0) {
      _messages[index] = _messages[index].copyWith(
        isPinned: event.pinned,
        pinnedBy: event.pinned ? event.userId : null,
        pinnedAt: event.pinned ? DateTime.now() : null,
      );
      notifyListeners();
    }
  }

  void _handleReadReceipt(ReadReceipt receipt) {
    _otherUserLastRead = receipt.readAt;
    notifyListeners();
  }

  void _handlePresenceChange(PresenceEvent event) {
    if (event.isOnline) {
      _onlineUsers.add(event.userId);
    } else {
      _onlineUsers.remove(event.userId);
    }
    notifyListeners();
  }

  final Map<String, Timer> _typingTimers = {};

  void _handleTypingEvent(TypingEvent event) {
    if (event.isTyping) {
      _typingUsers.add(event.userId);

      // Auto-remove after 3 seconds
      _typingTimers[event.userId]?.cancel();
      _typingTimers[event.userId] = Timer(const Duration(seconds: 3), () {
        _typingUsers.remove(event.userId);
        notifyListeners();
      });
    } else {
      _typingUsers.remove(event.userId);
      _typingTimers[event.userId]?.cancel();
    }
    notifyListeners();
  }

  // ============ Actions ============

  /// Refreshes all messages.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await client.getMessages(roomId);
      _messages = result.messages.reversed.toList(); // Reverse: API returns oldest first
      _hasMore = result.hasMore;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads more (older) messages.
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // _messages is newest first, so .last is the oldest message
      final result = await client.getMessages(
        roomId,
        before: _messages.last.id,
      );
      // API returns oldest first, reverse to get newest first, then add to end (older messages)
      _messages.addAll(result.messages.reversed);
      _hasMore = result.hasMore;
    } catch (e) {
      _error = e;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Sends a message.
  Future<void> sendMessage({
    required String content,
    MessageType type = MessageType.text,
    List<Attachment>? attachments,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    // Optimistic update with pending message
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pendingMessage = Message(
      id: pendingId,
      roomId: roomId,
      senderUserId: client.config.userId,
      content: content,
      type: type,
      attachments: attachments,
      metadata: metadata,
      replyToId: replyToId,
      createdAt: DateTime.now(),
      isPending: true,
    );

    _messages.insert(0, pendingMessage);
    notifyListeners();

    try {
      final sent = await client.sendMessage(
        roomId,
        content: content,
        type: type,
        attachments: attachments,
        metadata: metadata,
        replyToId: replyToId,
      );

      // Replace pending with real message
      final index = _messages.indexWhere((m) => m.id == pendingId);
      if (index >= 0) {
        _messages[index] = sent;
        notifyListeners();
      }
    } catch (e) {
      // Mark as failed
      final index = _messages.indexWhere((m) => m.id == pendingId);
      if (index >= 0) {
        _messages[index] = pendingMessage.copyWith(
          isPending: false,
          isFailed: true,
        );
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Retries a failed message.
  Future<void> retryMessage(Message failedMessage) async {
    if (!failedMessage.isFailed) return;

    // Remove failed message
    _messages.removeWhere((m) => m.id == failedMessage.id);
    notifyListeners();

    // Resend
    await sendMessage(
      content: failedMessage.content,
      type: failedMessage.type,
      attachments: failedMessage.attachments,
      metadata: failedMessage.metadata,
      replyToId: failedMessage.replyToId,
    );
  }

  /// Deletes a message.
  Future<void> deleteMessage(String messageId) async {
    await client.deleteMessage(messageId);
    // Server will send deletion event
  }

  /// Edits a message.
  Future<void> editMessage(String messageId, {required String content}) async {
    await client.editMessage(messageId, content: content);
    // Server will send edit event
  }

  /// Marks messages as read.
  Future<void> markAsRead() async {
    await client.markAsRead(roomId);
  }

  /// Adds a reaction.
  Future<void> addReaction(String messageId, {required String emoji}) async {
    await client.addReaction(messageId, emoji: emoji);
  }

  /// Removes a reaction.
  Future<void> removeReaction(String messageId, {required String emoji}) async {
    await client.removeReaction(messageId, emoji: emoji);
  }

  /// Pins a message.
  Future<void> pinMessage(String messageId) async {
    await client.pinMessage(messageId);
  }

  /// Unpins a message.
  Future<void> unpinMessage(String messageId) async {
    await client.unpinMessage(messageId);
  }

  /// Publishes a typing indicator.
  DateTime? _lastTypingPublish;
  Future<void> publishTyping() async {
    final now = DateTime.now();
    if (_lastTypingPublish != null &&
        now.difference(_lastTypingPublish!).inSeconds < 2) {
      return; // Throttle
    }
    _lastTypingPublish = now;
    await client.publishTyping(roomId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    client.leaveRoom(roomId);
    super.dispose();
  }
}

/// Provides ChatChannelState to a subtree.
///
/// Use this widget to scope chat functionality to a specific room.
///
/// ```dart
/// ChatChannelScope(
///   roomId: 'room-123',
///   child: ChatScreen(),
/// )
/// ```
class ChatChannelScope extends StatefulWidget {
  /// The room ID to connect to.
  final String roomId;

  /// The child widget.
  final Widget child;

  /// Called when an error occurs.
  final void Function(Object error)? onError;

  const ChatChannelScope({
    super.key,
    required this.roomId,
    required this.child,
    this.onError,
  });

  /// Gets the ChatChannelState from the nearest ancestor.
  static ChatChannelState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ChatChannelInherited>();
    if (scope == null) {
      throw FlutterError(
        'ChatChannelScope.of() called with a context that does not contain a ChatChannelScope.\n'
        'Ensure that ChatChannelScope is an ancestor of the widget calling ChatChannelScope.of().',
      );
    }
    return scope.state;
  }

  /// Gets the ChatChannelState without establishing a dependency.
  static ChatChannelState read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<_ChatChannelInherited>();
    if (scope == null) {
      throw FlutterError(
        'ChatChannelScope.read() called with a context that does not contain a ChatChannelScope.\n'
        'Ensure that ChatChannelScope is an ancestor of the widget calling ChatChannelScope.read().',
      );
    }
    return scope.state;
  }

  @override
  State<ChatChannelScope> createState() => _ChatChannelScopeState();
}

class _ChatChannelScopeState extends State<ChatChannelScope> {
  late ChatChannelState _state;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() {
    final client = RiviumChatScope.read(context);
    _state = ChatChannelState(client: client, roomId: widget.roomId);
    _state.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (_state.hasError && widget.onError != null) {
      widget.onError!(_state.error!);
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(ChatChannelScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _state.removeListener(_onStateChange);
      _state.dispose();
      _initState();
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChange);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ChatChannelInherited(
      state: _state,
      child: widget.child,
    );
  }
}

class _ChatChannelInherited extends InheritedNotifier<ChatChannelState> {
  final ChatChannelState state;

  const _ChatChannelInherited({
    required this.state,
    required super.child,
  }) : super(notifier: state);
}
