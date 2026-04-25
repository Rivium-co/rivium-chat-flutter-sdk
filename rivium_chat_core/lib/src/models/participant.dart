import 'enums.dart';

/// Represents a participant in a chat room.
class Participant {
  final String id;
  final String externalUserId;
  final String? displayName;
  final String? locale;
  final ParticipantRole role;
  final DateTime? lastReadAt;
  final DateTime joinedAt;

  const Participant({
    required this.id,
    required this.externalUserId,
    this.displayName,
    this.locale,
    this.role = ParticipantRole.member,
    this.lastReadAt,
    required this.joinedAt,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      externalUserId: json['externalUserId'] as String,
      displayName: json['displayName'] as String?,
      locale: json['locale'] as String?,
      role: _parseRole(json['role']),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.parse(json['lastReadAt'] as String)
          : null,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  static ParticipantRole _parseRole(dynamic role) {
    if (role == null) return ParticipantRole.member;
    if (role is String) {
      return ParticipantRole.values.firstWhere(
        (e) => e.name == role,
        orElse: () => ParticipantRole.member,
      );
    }
    return ParticipantRole.member;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'externalUserId': externalUserId,
      if (displayName != null) 'displayName': displayName,
      if (locale != null) 'locale': locale,
      'role': role.name,
      if (lastReadAt != null) 'lastReadAt': lastReadAt!.toIso8601String(),
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  Participant copyWith({
    String? id,
    String? externalUserId,
    String? displayName,
    String? locale,
    ParticipantRole? role,
    DateTime? lastReadAt,
    DateTime? joinedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      externalUserId: externalUserId ?? this.externalUserId,
      displayName: displayName ?? this.displayName,
      locale: locale ?? this.locale,
      role: role ?? this.role,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Participant &&
        other.id == id &&
        other.externalUserId == externalUserId &&
        other.displayName == displayName &&
        other.locale == locale &&
        other.role == role &&
        other.lastReadAt == lastReadAt &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        externalUserId,
        displayName,
        locale,
        role,
        lastReadAt,
        joinedAt,
      );

  @override
  String toString() {
    return 'Participant(id: $id, externalUserId: $externalUserId, displayName: $displayName, locale: $locale, role: $role, lastReadAt: $lastReadAt, joinedAt: $joinedAt)';
  }
}
