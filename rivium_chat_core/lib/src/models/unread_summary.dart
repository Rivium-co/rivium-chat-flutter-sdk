import 'package:flutter/foundation.dart';

/// Summary of unread messages across all rooms.
class UnreadSummary {
  final int totalUnread;
  final List<RoomUnread> rooms;

  const UnreadSummary({
    required this.totalUnread,
    required this.rooms,
  });

  factory UnreadSummary.fromJson(Map<String, dynamic> json) {
    return UnreadSummary(
      totalUnread: json['totalUnread'] as int,
      rooms: (json['rooms'] as List<dynamic>)
          .map((e) => RoomUnread.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalUnread': totalUnread,
      'rooms': rooms.map((e) => e.toJson()).toList(),
    };
  }

  UnreadSummary copyWith({
    int? totalUnread,
    List<RoomUnread>? rooms,
  }) {
    return UnreadSummary(
      totalUnread: totalUnread ?? this.totalUnread,
      rooms: rooms ?? this.rooms,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnreadSummary &&
        other.totalUnread == totalUnread &&
        listEquals(other.rooms, rooms);
  }

  @override
  int get hashCode => Object.hash(totalUnread, Object.hashAll(rooms));

  @override
  String toString() {
    return 'UnreadSummary(totalUnread: $totalUnread, rooms: $rooms)';
  }
}

/// Unread count for a specific room.
class RoomUnread {
  final String roomId;
  final String? externalId;
  final int unreadCount;

  const RoomUnread({
    required this.roomId,
    this.externalId,
    required this.unreadCount,
  });

  factory RoomUnread.fromJson(Map<String, dynamic> json) {
    return RoomUnread(
      roomId: json['roomId'] as String,
      externalId: json['externalId'] as String?,
      unreadCount: json['unreadCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      if (externalId != null) 'externalId': externalId,
      'unreadCount': unreadCount,
    };
  }

  RoomUnread copyWith({
    String? roomId,
    String? externalId,
    int? unreadCount,
  }) {
    return RoomUnread(
      roomId: roomId ?? this.roomId,
      externalId: externalId ?? this.externalId,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomUnread &&
        other.roomId == roomId &&
        other.externalId == externalId &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode => Object.hash(roomId, externalId, unreadCount);

  @override
  String toString() {
    return 'RoomUnread(roomId: $roomId, externalId: $externalId, unreadCount: $unreadCount)';
  }
}
