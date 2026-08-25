import 'dart:async';
import 'dart:convert';
import 'package:centrifuge/centrifuge.dart' as centrifuge;
import '../config.dart';
import '../models/models.dart';
import '../events/events.dart';

/// Real-time messaging service using Centrifugo WebSocket.
class RealtimeService {
  final RiviumChatConfig _config;
  final Future<String> Function() _getToken;

  centrifuge.Client? _client;
  final Map<String, centrifuge.Subscription> _subscriptions = {};

  // Connection state
  final _connectionStateController =
      StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;
  ConnectionState _currentState = ConnectionState.disconnected;
  ConnectionState get currentConnectionState => _currentState;

  // Event streams
  final _messageController = StreamController<Message>.broadcast();
  final _readReceiptController = StreamController<ReadReceipt>.broadcast();
  final _deletionController = StreamController<MessageDeletion>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _presenceController = StreamController<PresenceEvent>.broadcast();
  final _reactionController = StreamController<ReactionEvent>.broadcast();
  final _editController = StreamController<MessageEditEvent>.broadcast();
  final _pinController = StreamController<MessagePinEvent>.broadcast();
  final _errorController = StreamController<ConnectionErrorEvent>.broadcast();
  final _subscriptionStateController =
      StreamController<SubscriptionStateEvent>.broadcast();
  final _recoveryFailedController = StreamController<String>.broadcast();
  final _parseErrorController =
      StreamController<RealtimeParseError>.broadcast();

  /// Stream of incoming messages.
  Stream<Message> get onMessage => _messageController.stream;

  /// Stream of read receipts.
  Stream<ReadReceipt> get onReadReceipt => _readReceiptController.stream;

  /// Stream of message deletions.
  Stream<MessageDeletion> get onMessageDeleted => _deletionController.stream;

  /// Stream of typing events.
  Stream<TypingEvent> get onTypingEvent => _typingController.stream;

  /// Stream of presence changes.
  Stream<PresenceEvent> get onPresenceChange => _presenceController.stream;

  /// Stream of reaction events.
  Stream<ReactionEvent> get onReactionEvent => _reactionController.stream;

  /// Stream of message edits.
  Stream<MessageEditEvent> get onMessageEdited => _editController.stream;

  /// Stream of pin/unpin events.
  Stream<MessagePinEvent> get onMessagePinChanged => _pinController.stream;

  /// Stream of connection errors.
  Stream<ConnectionErrorEvent> get onConnectionError => _errorController.stream;

  /// Stream of subscription state changes.
  Stream<SubscriptionStateEvent> get onSubscriptionState =>
      _subscriptionStateController.stream;

  /// Stream of recovery failures (room IDs that need full refresh).
  Stream<String> get onRecoveryFailed => _recoveryFailedController.stream;

  /// Stream of realtime frames that arrived but couldn't be parsed or
  /// dispatched. Prior to 0.1.1 these were silently swallowed, which
  /// masked "missing message" bugs. Wire this to your telemetry to
  /// catch schema drift between server and client.
  Stream<RealtimeParseError> get onParseError => _parseErrorController.stream;

  RealtimeService(this._config, this._getToken);

  void _updateState(ConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Connects to the Centrifugo server.
  Future<void> connect() async {
    if (_client != null) return;

    _updateState(ConnectionState.connecting);

    try {
      final token = await _getToken();

      _client = centrifuge.createClient(
        RiviumChatConfig.centrifugoUrl,
        centrifuge.ClientConfig(
          token: token,
          getToken: (event) async => await _getToken(),
        ),
      );

      _client!.connecting.listen((event) {
        _updateState(ConnectionState.connecting);
      });

      _client!.connected.listen((event) {
        _updateState(ConnectionState.connected);
      });

      _client!.disconnected.listen((event) {
        _updateState(ConnectionState.disconnected);
        if (event.reason.isNotEmpty) {
          _errorController
              .add(ConnectionErrorEvent(error: 'Disconnected: ${event.reason}'));
        }
      });

      _client!.error.listen((event) {
        _updateState(ConnectionState.error);
        _errorController.add(ConnectionErrorEvent(error: event.error));
      });

      await _client!.connect();
    } catch (e) {
      _updateState(ConnectionState.error);
      _errorController.add(ConnectionErrorEvent(error: e));
      rethrow;
    }
  }

  /// Disconnects from the Centrifugo server.
  Future<void> disconnect() async {
    if (_client == null) return;

    for (final sub in _subscriptions.values) {
      await sub.unsubscribe();
    }
    _subscriptions.clear();

    await _client!.disconnect();
    _client = null;
    _updateState(ConnectionState.disconnected);
  }

  /// Subscribes to a room's channels.
  Future<void> subscribeRoom(String roomId) async {
    if (_client == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    // Subscribe to chat channel (messages, read receipts, etc.)
    await _subscribeToChannel(
      'chat:room_$roomId',
      roomId,
      recoverable: true,
      onPublication: (data) => _handleChatEvent(roomId, data),
      onRecoveryFailed: () => _recoveryFailedController.add(roomId),
    );

    // Subscribe to presence channel
    await _subscribeToChannel(
      'presence:room_$roomId',
      roomId,
      onJoin: (userId) => _presenceController.add(PresenceEvent(
        roomId: roomId,
        userId: userId,
        isOnline: true,
      )),
      onLeave: (userId) => _presenceController.add(PresenceEvent(
        roomId: roomId,
        userId: userId,
        isOnline: false,
      )),
    );

    // Subscribe to typing channel
    await _subscribeToChannel(
      'typing:room_$roomId',
      roomId,
      onPublication: (data) {
        final userId = data['userId'] as String?;
        if (userId != null && userId != _config.userId) {
          _typingController.add(TypingEvent(
            roomId: roomId,
            userId: userId,
            isTyping: data['isTyping'] as bool? ?? true,
          ));
        }
      },
    );
  }

  Future<void> _subscribeToChannel(
    String channel,
    String roomId, {
    bool recoverable = false,
    void Function(Map<String, dynamic>)? onPublication,
    void Function(String userId)? onJoin,
    void Function(String userId)? onLeave,
    void Function()? onRecoveryFailed,
  }) async {
    if (_subscriptions.containsKey(channel)) return;

    final sub = _client!.newSubscription(
      channel,
      centrifuge.SubscriptionConfig(
        recoverable: recoverable,
        joinLeave: onJoin != null || onLeave != null,
      ),
    );

    sub.subscribing.listen((event) {
      _subscriptionStateController.add(SubscriptionStateEvent(
        roomId: roomId,
        channel: channel,
        status: SubscriptionStatus.subscribing,
      ));
    });

    sub.subscribed.listen((event) {
      _subscriptionStateController.add(SubscriptionStateEvent(
        roomId: roomId,
        channel: channel,
        status: SubscriptionStatus.subscribed,
      ));

      // Check for recovery failure
      if (recoverable && event.wasRecovering && !event.recovered) {
        onRecoveryFailed?.call();
      }

      // Query current presence on subscribe to detect users who joined before us
      if (onJoin != null && channel.startsWith('presence:')) {
        sub.presence().then((result) {
          for (final client in result.clients.values) {
            if (client.user.isNotEmpty) {
              onJoin(client.user);
            }
          }
        }).catchError((_) {});
      }
    });

    sub.unsubscribed.listen((event) {
      _subscriptionStateController.add(SubscriptionStateEvent(
        roomId: roomId,
        channel: channel,
        status: SubscriptionStatus.unsubscribed,
        code: event.code,
        reason: event.reason,
      ));
    });

    sub.publication.listen((event) {
      // Decode step: a decode failure means the frame is truly garbage
      // (rare — Centrifugo speaks binary-safe JSON). Report it and
      // move on.
      Map<String, dynamic>? data;
      try {
        data = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>?;
      } catch (e, st) {
        _parseErrorController.add(RealtimeParseError(
          channel: channel,
          roomId: roomId,
          error: e,
          stackTrace: st,
        ));
        return;
      }
      if (data == null || onPublication == null) return;
      // Dispatch step: keep this OUTSIDE the decode try so a per-event
      // parse failure in `_handleChatEvent` doesn't get confused with a
      // JSON decode error. `_handleChatEvent` catches per-case and
      // reports through the same `_parseErrorController`.
      onPublication(data);
    });

    if (onJoin != null) {
      sub.join.listen((event) {
        final userId = event.user;
        if (userId.isNotEmpty) {
          onJoin(userId);
        }
      });
    }

    if (onLeave != null) {
      sub.leave.listen((event) {
        final userId = event.user;
        if (userId.isNotEmpty) {
          onLeave(userId);
        }
      });
    }

    _subscriptions[channel] = sub;
    await sub.subscribe();
  }

  void _handleChatEvent(String roomId, Map<String, dynamic> data) {
    // Backend sends 'event' field, but also support 'type' for backwards compatibility
    final eventType = data['event'] as String? ?? data['type'] as String?;
    final payload = data['data'] as Map<String, dynamic>? ?? data;

    // Every case wraps the dispatch in its own try. A schema drift on
    // one event type (e.g. server adds a required field to `message`)
    // must NOT break the entire subscription lane — that was the
    // pre-0.1.1 behavior which silently dropped realtime frames.
    try {
      switch (eventType) {
        case 'message':
          _messageController.add(Message.fromJson(payload));
          break;
        case 'read':
          _readReceiptController.add(ReadReceipt.fromJson(payload));
          break;
        case 'deleted':
          _deletionController.add(MessageDeletion.fromJson(payload));
          break;
        case 'message_edited':
          _editController.add(MessageEditEvent(
            messageId: payload['messageId'] as String,
            roomId: payload['roomId'] as String? ?? roomId,
            content: payload['content'] as String,
            editedBy: payload['editedBy'] as String,
            editedAt: DateTime.parse(payload['editedAt'] as String),
          ));
          break;
        case 'reaction_added':
          _reactionController.add(ReactionEvent(
            messageId: payload['messageId'] as String,
            roomId: payload['roomId'] as String? ?? roomId,
            userId: payload['userId'] as String,
            emoji: payload['emoji'] as String,
            added: true,
            reactionId: payload['reactionId'] as String?,
          ));
          break;
        case 'reaction_removed':
          _reactionController.add(ReactionEvent(
            messageId: payload['messageId'] as String,
            roomId: payload['roomId'] as String? ?? roomId,
            userId: payload['userId'] as String,
            emoji: payload['emoji'] as String,
            added: false,
          ));
          break;
        case 'message_pinned':
          _pinController.add(MessagePinEvent(
            messageId: payload['messageId'] as String,
            roomId: payload['roomId'] as String? ?? roomId,
            userId: payload['pinnedBy'] as String,
            pinned: true,
          ));
          break;
        case 'message_unpinned':
          _pinController.add(MessagePinEvent(
            messageId: payload['messageId'] as String,
            roomId: payload['roomId'] as String? ?? roomId,
            userId: payload['unpinnedBy'] as String,
            pinned: false,
          ));
          break;
        default:
          // Try parsing as a direct message if no type specified
          if (payload.containsKey('id') && payload.containsKey('content')) {
            _messageController.add(Message.fromJson(payload));
          }
      }
    } catch (e, st) {
      _parseErrorController.add(RealtimeParseError(
        channel: 'chat:room_$roomId',
        roomId: roomId,
        eventType: eventType,
        payload: payload,
        error: e,
        stackTrace: st,
      ));
    }
  }

  /// Subscribe only to a room's chat channel (messages, read receipts) without presence/typing.
  /// Used for unread badge updates without appearing online.
  Future<void> observeRoom(String roomId) async {
    if (_client == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    await _subscribeToChannel(
      'chat:room_$roomId',
      roomId,
      recoverable: true,
      onPublication: (data) => _handleChatEvent(roomId, data),
      onRecoveryFailed: () => _recoveryFailedController.add(roomId),
    );
  }

  /// Unsubscribes from a room's channels.
  Future<void> unsubscribeRoom(String roomId) async {
    final channels = [
      'chat:room_$roomId',
      'presence:room_$roomId',
      'typing:room_$roomId',
    ];

    for (final channel in channels) {
      final sub = _subscriptions.remove(channel);
      if (sub != null) {
        await sub.unsubscribe();
        // Also remove from Centrifuge client's internal registry
        // to allow re-subscribing later
        _client?.removeSubscription(sub);
      }
    }
  }

  /// Leave presence and typing channels but keep chat channel for unread updates.
  Future<void> leaveRoom(String roomId) async {
    final channels = [
      'presence:room_$roomId',
      'typing:room_$roomId',
    ];

    for (final channel in channels) {
      final sub = _subscriptions.remove(channel);
      if (sub != null) {
        await sub.unsubscribe();
        _client?.removeSubscription(sub);
      }
    }
  }

  /// Gets currently online users in a room.
  Future<Set<String>> getRoomPresence(String roomId) async {
    final channel = 'presence:room_$roomId';
    final sub = _subscriptions[channel];
    if (sub == null) return {};

    try {
      final result = await sub.presence();
      return result.clients.values.map((c) => c.user).where((u) => u.isNotEmpty).toSet();
    } catch (e) {
      return {};
    }
  }

  DateTime _lastTypingTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Publishes a typing indicator (throttled to 2 seconds).
  Future<void> publishTyping(String roomId) async {
    final now = DateTime.now();
    if (now.difference(_lastTypingTime).inMilliseconds < 2000) return;
    _lastTypingTime = now;

    final channel = 'typing:room_$roomId';
    final sub = _subscriptions[channel];
    if (sub == null) return;

    try {
      final data = utf8.encode(jsonEncode({
        'userId': _config.userId,
        'isTyping': true,
      }));
      await sub.publish(data);
    } catch (e) {
      // Ignore typing publish errors
    }
  }

  /// Disposes all resources.
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _messageController.close();
    _readReceiptController.close();
    _deletionController.close();
    _typingController.close();
    _presenceController.close();
    _reactionController.close();
    _editController.close();
    _pinController.close();
    _errorController.close();
    _subscriptionStateController.close();
    _recoveryFailedController.close();
    _parseErrorController.close();
  }
}
