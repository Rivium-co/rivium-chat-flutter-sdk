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

  /// Channels that have reached the `subscribed` state. A channel present in
  /// [_subscriptions] but absent here was created but never confirmed by the
  /// server — it must not be treated as usable.
  final Set<String> _subscribedChannels = {};

  /// Serialises operations per channel.
  ///
  /// Subscribe and unsubscribe both hand the channel name back and forth with
  /// Centrifuge's internal registry. Interleaving them — which happens
  /// constantly on mobile, where a screen leaves a room and rejoins it across
  /// a lifecycle event without awaiting — leaves the two registries
  /// disagreeing and throws "Subscription to a channel already exists".
  /// Every mutation for a channel queues behind the previous one.
  final Map<String, Future<void>> _channelOps = {};

  /// Runs [action] after any in-flight operation for [channel] completes.
  Future<T> _lockChannel<T>(String channel, Future<T> Function() action) {
    final previous = _channelOps[channel] ?? Future<void>.value();
    final result = previous.then((_) => action());
    // Keep the chain alive even when a link fails, or one error would wedge
    // the channel permanently.
    _channelOps[channel] = result.then((_) {}, onError: (_) {});
    return result;
  }

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

  /// Builds the Centrifuge client. Overridable so tests can drive the
  /// subscribe/unsubscribe lifecycle without a server.
  final centrifuge.Client Function(String url, centrifuge.ClientConfig config)?
      clientFactory;

  /// How long to wait for the server to confirm a subscribe before treating
  /// it as failed.
  final Duration subscribeTimeout;

  RealtimeService(
    this._config,
    this._getToken, {
    this.clientFactory,
    this.subscribeTimeout = const Duration(seconds: 10),
  });

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

      _client = (clientFactory ?? centrifuge.createClient)(
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

    // Free every channel in Centrifuge's registry as well as our own map.
    // Dropping only our map left the names held by the client, so every
    // channel threw "already exists" on the next subscribe — for the life of
    // the process.
    for (final channel in _subscriptions.keys.toList()) {
      await _teardownChannel(channel);
    }
    _subscriptions.clear();
    _subscribedChannels.clear();
    _channelOps.clear();

    await _client!.disconnect();
    _client = null;
    _updateState(ConnectionState.disconnected);
  }

  /// Drops the current connection and opens a new one.
  ///
  /// [connect] is a no-op while a client object exists, which leaves a host
  /// with no way to recover a socket it believes is stale — a common state
  /// after a long background on mobile. This tears the client down first, so
  /// reconnecting is always possible.
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  /// Subscribes to a room's channels.
  Future<void> subscribeRoom(String roomId) async {
    if (_client == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    // Each channel is subscribed independently. Sequential awaits meant a
    // failure on the chat channel skipped presence and typing entirely, and a
    // failure on any of them discarded the ones that had already succeeded.
    final results = await Future.wait([
      // Subscribe to chat channel (messages, read receipts, etc.)
      _subscribeToChannel(
      'chat:room_$roomId',
      roomId,
      recoverable: true,
      onPublication: (data) => _handleChatEvent(roomId, data),
      onRecoveryFailed: () => _recoveryFailedController.add(roomId),
      ).then<Object?>((_) => null, onError: (Object e) => e),

      // Subscribe to presence channel
      _subscribeToChannel(
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
      ).then<Object?>((_) => null, onError: (Object e) => e),

      // Subscribe to typing channel
      _subscribeToChannel(
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
      ).then<Object?>((_) => null, onError: (Object e) => e),
    ]);

    // Surface a failure only after every channel has had its turn, so a
    // partial subscription keeps whatever succeeded.
    final failures = results.whereType<Object>().toList();
    if (failures.isNotEmpty) {
      throw StateError(
        'subscribeRoom($roomId) failed on ${failures.length} of 3 channels: '
        '${failures.map((e) => e.toString()).join('; ')}',
      );
    }
  }

  /// Whether every channel for [roomId] is currently subscribed.
  ///
  /// Lets a host detect the "opened but realtime-dead" state that previously
  /// had no signal at all.
  bool isRoomSubscribed(String roomId) =>
      _subscribedChannels.contains('chat:room_$roomId') &&
      _subscribedChannels.contains('presence:room_$roomId') &&
      _subscribedChannels.contains('typing:room_$roomId');

  /// Channels of [roomId] that are currently subscribed.
  Set<String> subscribedChannelsFor(String roomId) => {
        for (final c in ['chat', 'presence', 'typing'])
          if (_subscribedChannels.contains('$c:room_$roomId')) '$c:room_$roomId',
      };

  Future<void> _subscribeToChannel(
    String channel,
    String roomId, {
    bool recoverable = false,
    void Function(Map<String, dynamic>)? onPublication,
    void Function(String userId)? onJoin,
    void Function(String userId)? onLeave,
    void Function()? onRecoveryFailed,
  }) async {
    return _lockChannel(channel, () => _subscribeToChannelLocked(
          channel,
          roomId,
          recoverable: recoverable,
          onPublication: onPublication,
          onJoin: onJoin,
          onLeave: onLeave,
          onRecoveryFailed: onRecoveryFailed,
        ));
  }

  Future<void> _subscribeToChannelLocked(
    String channel,
    String roomId, {
    bool recoverable = false,
    void Function(Map<String, dynamic>)? onPublication,
    void Function(String userId)? onJoin,
    void Function(String userId)? onLeave,
    void Function()? onRecoveryFailed,
  }) async {
    // Already live — nothing to do.
    if (_subscribedChannels.contains(channel)) return;

    // A subscription object exists but never reached `subscribed`: a previous
    // attempt was rejected or dropped. Returning here is what made
    // subscribeRoom report success while the channel stayed dead, so tear the
    // stale object down and build a fresh one instead.
    final stale = _subscriptions.remove(channel);
    if (stale != null) {
      _client?.removeSubscription(stale);
      try {
        await stale.unsubscribe();
      } catch (_) {
        // Already gone; the registry removal above is what matters.
      }
    }

    // Resolved by the `subscribed` listener, rejected by the `error` one.
    // `subscribe()` returns as soon as the request is dispatched, so without
    // waiting on a real outcome the caller is told "subscribed" for a channel
    // the server went on to reject.
    final outcome = Completer<void>();

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
      _subscribedChannels.add(channel);
      if (!outcome.isCompleted) outcome.complete();
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
      _subscribedChannels.remove(channel);
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

    // A rejected subscribe surfaces here and nowhere else. Without this
    // listener the channel stayed silently dead and every later
    // subscribeRoom() returned "success" without sending anything.
    sub.error.listen((event) {
      _subscribedChannels.remove(channel);
      if (!outcome.isCompleted) {
        outcome.completeError(
          StateError('subscribe to $channel failed: ${event.error}'),
        );
      }
      _subscriptionStateController.add(SubscriptionStateEvent(
        roomId: roomId,
        channel: channel,
        status: SubscriptionStatus.error,
        reason: event.error.toString(),
      ));
      _errorController.add(
        ConnectionErrorEvent(error: 'Subscription failed on $channel: ${event.error}'),
      );
    });

    _subscriptions[channel] = sub;
    await sub.subscribe();

    try {
      await outcome.future.timeout(subscribeTimeout);
    } catch (e) {
      // Leave nothing half-registered: drop the dead subscription so a retry
      // builds a fresh one rather than hitting the "already subscribed" path.
      _subscriptions.remove(channel);
      _subscribedChannels.remove(channel);
      _client?.removeSubscription(sub);
      rethrow;
    }
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

  /// Tears one channel down.
  ///
  /// The Centrifuge registry is cleared **before** awaiting `unsubscribe()`.
  /// The old order — remove from our map, await the network round-trip, then
  /// free the Centrifuge entry — left a window in which our map said "free"
  /// while Centrifuge still held the name, so a re-subscribe arriving in that
  /// window threw "Subscription to a channel already exists". On iOS the
  /// window is wide, because backgrounding suspends the socket and the
  /// unsubscribe round-trip cannot complete.
  Future<void> _teardownChannel(String channel) async {
    final sub = _subscriptions.remove(channel);
    _subscribedChannels.remove(channel);
    if (sub == null) return;

    // Free the name first, so the channel is immediately re-subscribable.
    _client?.removeSubscription(sub);
    try {
      await sub.unsubscribe();
    } catch (_) {
      // The socket may already be gone. The registry removal above is the
      // part that must not be skipped.
    }
  }

  /// Unsubscribes from a room's channels.
  Future<void> unsubscribeRoom(String roomId) async {
    final channels = [
      'chat:room_$roomId',
      'presence:room_$roomId',
      'typing:room_$roomId',
    ];

    await Future.wait([
      for (final channel in channels)
        _lockChannel(channel, () => _teardownChannel(channel)),
    ]);
  }

  /// Leave presence and typing channels but keep chat channel for unread updates.
  Future<void> leaveRoom(String roomId) async {
    final channels = [
      'presence:room_$roomId',
      'typing:room_$roomId',
    ];

    await Future.wait([
      for (final channel in channels)
        _lockChannel(channel, () => _teardownChannel(channel)),
    ]);
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
