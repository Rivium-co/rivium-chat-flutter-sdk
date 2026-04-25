import 'package:flutter/foundation.dart';
import 'attachment.dart';
import 'reaction.dart';
import 'enums.dart';

/// Represents a chat message.
class Message {
  final String id;
  final String roomId;
  final String senderUserId;
  final String content;
  final MessageType type;
  final List<Attachment>? attachments;
  final Map<String, dynamic>? metadata;
  final String? replyToId;
  final Message? replyTo;
  final bool isDeleted;
  final DateTime createdAt;
  final bool isEdited;
  final DateTime? editedAt;
  final List<Map<String, dynamic>>? editHistory;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? pinnedBy;
  final List<Reaction>? reactions;
  // Local state flags (not persisted)
  final bool isPending;
  final bool isFailed;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderUserId,
    required this.content,
    this.type = MessageType.text,
    this.attachments,
    this.metadata,
    this.replyToId,
    this.replyTo,
    this.isDeleted = false,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.editHistory,
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedBy,
    this.reactions,
    this.isPending = false,
    this.isFailed = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderUserId: json['senderUserId'] as String,
      content: json['content'] as String? ?? '',
      type: _parseMessageType(json['type']),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      replyToId: json['replyToId'] as String?,
      replyTo: json['replyTo'] != null
          ? Message.fromJson(json['replyTo'] as Map<String, dynamic>)
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
      editHistory: (json['editHistory'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedAt: json['pinnedAt'] != null
          ? DateTime.parse(json['pinnedAt'] as String)
          : null,
      pinnedBy: json['pinnedBy'] as String?,
      reactions: (json['reactions'] as List<dynamic>?)
          ?.map((e) => Reaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      isPending: json['isPending'] as bool? ?? false,
      isFailed: json['isFailed'] as bool? ?? false,
    );
  }

  static MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    if (type is String) {
      return MessageType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => MessageType.text,
      );
    }
    return MessageType.text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderUserId': senderUserId,
      'content': content,
      'type': type.name,
      if (attachments != null)
        'attachments': attachments!.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyTo != null) 'replyTo': replyTo!.toJson(),
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'isEdited': isEdited,
      if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      if (editHistory != null) 'editHistory': editHistory,
      'isPinned': isPinned,
      if (pinnedAt != null) 'pinnedAt': pinnedAt!.toIso8601String(),
      if (pinnedBy != null) 'pinnedBy': pinnedBy,
      if (reactions != null)
        'reactions': reactions!.map((e) => e.toJson()).toList(),
      'isPending': isPending,
      'isFailed': isFailed,
    };
  }

  Message copyWith({
    String? id,
    String? roomId,
    String? senderUserId,
    String? content,
    MessageType? type,
    List<Attachment>? attachments,
    Map<String, dynamic>? metadata,
    String? replyToId,
    Message? replyTo,
    bool? isDeleted,
    DateTime? createdAt,
    bool? isEdited,
    DateTime? editedAt,
    List<Map<String, dynamic>>? editHistory,
    bool? isPinned,
    DateTime? pinnedAt,
    String? pinnedBy,
    List<Reaction>? reactions,
    bool? isPending,
    bool? isFailed,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderUserId: senderUserId ?? this.senderUserId,
      content: content ?? this.content,
      type: type ?? this.type,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      editHistory: editHistory ?? this.editHistory,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      reactions: reactions ?? this.reactions,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.roomId == roomId &&
        other.senderUserId == senderUserId &&
        other.content == content &&
        other.type == type &&
        listEquals(other.attachments, attachments) &&
        mapEquals(other.metadata, metadata) &&
        other.replyToId == replyToId &&
        other.replyTo == replyTo &&
        other.isDeleted == isDeleted &&
        other.createdAt == createdAt &&
        other.isEdited == isEdited &&
        other.editedAt == editedAt &&
        listEquals(other.editHistory, editHistory) &&
        other.isPinned == isPinned &&
        other.pinnedAt == pinnedAt &&
        other.pinnedBy == pinnedBy &&
        listEquals(other.reactions, reactions) &&
        other.isPending == isPending &&
        other.isFailed == isFailed;
  }

  @override
  int get hashCode => Object.hash(
        id,
        roomId,
        senderUserId,
        content,
        type,
        attachments != null ? Object.hashAll(attachments!) : null,
        metadata,
        replyToId,
        replyTo,
        isDeleted,
        createdAt,
        isEdited,
        editedAt,
        editHistory != null ? Object.hashAll(editHistory!) : null,
        isPinned,
        pinnedAt,
        pinnedBy,
        reactions != null ? Object.hashAll(reactions!) : null,
        Object.hash(isPending, isFailed),
      );

  @override
  String toString() {
    return 'Message(id: $id, roomId: $roomId, senderUserId: $senderUserId, content: $content, type: $type, createdAt: $createdAt, isPending: $isPending, isFailed: $isFailed)';
  }
}

/// Paginated response for message queries.
class PaginatedMessages {
  final List<Message> messages;
  final bool hasMore;

  const PaginatedMessages({
    required this.messages,
    required this.hasMore,
  });

  factory PaginatedMessages.fromJson(Map<String, dynamic> json) {
    return PaginatedMessages(
      messages: (json['messages'] as List<dynamic>)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((e) => e.toJson()).toList(),
      'hasMore': hasMore,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaginatedMessages &&
        listEquals(other.messages, messages) &&
        other.hasMore == hasMore;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(messages), hasMore);

  @override
  String toString() {
    return 'PaginatedMessages(messages: ${messages.length}, hasMore: $hasMore)';
  }
}
