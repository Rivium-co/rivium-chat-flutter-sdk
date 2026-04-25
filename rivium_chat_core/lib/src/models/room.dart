import 'package:flutter/foundation.dart';
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
        listEquals(other.participants, participants);
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
      );

  @override
  String toString() {
    return 'Room(id: $id, type: $type, externalId: $externalId, name: $name, metadata: $metadata, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, participants: $participants)';
  }
}
