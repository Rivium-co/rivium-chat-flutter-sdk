import 'package:flutter/foundation.dart';
import 'message.dart';
import 'participant.dart';
import 'enums.dart';

/// Represents a chat room (conversation).
class Room {
  final String id;
  final RoomType type;
  final String? externalId;
  final String? name;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Participant> participants;

  /// The most recent message in the room, or null when there are none.
  ///
  /// Sent by `GET /rooms`, so a chat list can show a preview without asking
  /// for each room's messages.
  final Message? lastMessage;

  /// Messages from other people that arrived after this user last read the
  /// room. Sent by `GET /rooms`; 0 when everything has been read.
  final int unreadCount;

  const Room({
    required this.id,
    this.type = RoomType.direct,
    this.externalId,
    this.name,
    this.metadata,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      type: _parseRoomType(json['type']),
      externalId: json['externalId'] as String?,
      name: json['name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  static RoomType _parseRoomType(dynamic type) {
    if (type == null) return RoomType.direct;
    if (type is String) {
      return RoomType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => RoomType.direct,
      );
    }
    return RoomType.direct;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      if (externalId != null) 'externalId': externalId,
      if (name != null) 'name': name,
      if (metadata != null) 'metadata': metadata,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'participants': participants.map((e) => e.toJson()).toList(),
      if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
      'unreadCount': unreadCount,
    };
  }

  Room copyWith({
    String? id,
    RoomType? type,
    String? externalId,
    String? name,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Participant>? participants,
    Message? lastMessage,
    int? unreadCount,
  }) {
    return Room(
      id: id ?? this.id,
      type: type ?? this.type,
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Room &&
        other.id == id &&
        other.type == type &&
        other.externalId == externalId &&
        other.name == name &&
        mapEquals(other.metadata, metadata) &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        listEquals(other.participants, participants) &&
        other.lastMessage == lastMessage &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        externalId,
        name,
        metadata,
        isActive,
        createdAt,
        updatedAt,
        Object.hashAll(participants),
        lastMessage,
        unreadCount,
      );

  @override
  String toString() {
    return 'Room(id: $id, type: $type, externalId: $externalId, name: $name, metadata: $metadata, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, participants: $participants, lastMessage: $lastMessage, unreadCount: $unreadCount)';
  }
}
