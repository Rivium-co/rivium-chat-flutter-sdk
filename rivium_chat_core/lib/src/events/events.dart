import '../models/enums.dart';

/// Event emitted when a user reads messages in a room.
class ReadReceipt {
  final String userId;
  final String roomId;
  final DateTime readAt;

  const ReadReceipt({
    required this.userId,
    required this.roomId,
    required this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      userId: json['userId'] as String,
      roomId: json['roomId'] as String,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'roomId': roomId,
      'readAt': readAt.toIso8601String(),
    };
  }

  ReadReceipt copyWith({
    String? userId,
    String? roomId,
    DateTime? readAt,
  }) {
    return ReadReceipt(
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadReceipt &&
        other.userId == userId &&
        other.roomId == roomId &&
        other.readAt == readAt;
  }

  @override
  int get hashCode => Object.hash(userId, roomId, readAt);

  @override
  String toString() {
    return 'ReadReceipt(userId: $userId, roomId: $roomId, readAt: $readAt)';
  }
}

/// Event emitted when a message is deleted.
class MessageDeletion {
  final String messageId;
  final String roomId;
  final String deletedBy;

  const MessageDeletion({
    required this.messageId,
    required this.roomId,
    required this.deletedBy,
  });

  factory MessageDeletion.fromJson(Map<String, dynamic> json) {
    return MessageDeletion(
      messageId: json['messageId'] as String,
      roomId: json['roomId'] as String,
      deletedBy: json['deletedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'roomId': roomId,
      'deletedBy': deletedBy,
    };
  }

  MessageDeletion copyWith({
    String? messageId,
    String? roomId,
    String? deletedBy,
  }) {
    return MessageDeletion(
      messageId: messageId ?? this.messageId,
      roomId: roomId ?? this.roomId,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageDeletion &&
        other.messageId == messageId &&
        other.roomId == roomId &&
        other.deletedBy == deletedBy;
  }

  @override
  int get hashCode => Object.hash(messageId, roomId, deletedBy);

  @override
  String toString() {
    return 'MessageDeletion(messageId: $messageId, roomId: $roomId, deletedBy: $deletedBy)';
  }
}

/// Event emitted when a user is typing.
class TypingEvent {
  final String roomId;
  final String userId;
  final bool isTyping;

  const TypingEvent({
    required this.roomId,
    required this.userId,
    this.isTyping = true,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) => TypingEvent(
        roomId: json['roomId'] as String,
        userId: json['userId'] as String,
        isTyping: json['isTyping'] as bool? ?? true,
      );
}

/// Event emitted when a reaction is added or removed.
class ReactionEvent {
  final String messageId;
  final String roomId;
  final String userId;
  final String emoji;
  final bool added;
  final String? reactionId;

  const ReactionEvent({
    required this.messageId,
    required this.roomId,
    required this.userId,
    required this.emoji,
    required this.added,
    this.reactionId,
  });
}

/// Event emitted when a message is edited.
class MessageEditEvent {
  final String messageId;
  final String roomId;
  final String content;
  final String editedBy;
  final DateTime editedAt;

  const MessageEditEvent({
    required this.messageId,
    required this.roomId,
    required this.content,
    required this.editedBy,
    required this.editedAt,
  });
}

/// Event emitted when a message is pinned or unpinned.
class MessagePinEvent {
  final String messageId;
  final String roomId;
  final String userId;
  final bool pinned;

  const MessagePinEvent({
    required this.messageId,
    required this.roomId,
    required this.userId,
    required this.pinned,
  });
}

/// Event emitted when a connection error occurs.
class ConnectionErrorEvent {
  final Object error;

  const ConnectionErrorEvent({required this.error});
}

/// Event emitted when subscription state changes.
class SubscriptionStateEvent {
  final String roomId;
  final String channel;
  final SubscriptionStatus status;
  final int? code;
  final String? reason;

  const SubscriptionStateEvent({
    required this.roomId,
    required this.channel,
    required this.status,
    this.code,
    this.reason,
  });
}

/// Event emitted when user presence changes.
class PresenceEvent {
  final String roomId;
  final String userId;
  final bool isOnline;

  const PresenceEvent({
    required this.roomId,
    required this.userId,
    required this.isOnline,
  });
}
