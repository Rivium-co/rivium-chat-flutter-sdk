import '../models/attachment.dart';
import '../models/enums.dart';
import '../models/message.dart';

/// A message written while offline that waits in the outbox (only with
/// `RiviumChatConfig.queueOfflineMessages`).
///
/// [localId] is `local_<clientMessageId>`, the id of the pending [Message]
/// that `sendMessage` returned.
class PendingMessage {
  /// Prefix of a pending message's id.
  static const localIdPrefix = 'local_';

  final String clientMessageId;
  final String roomId;
  final String senderUserId;
  final String content;
  final MessageType type;
  final List<Attachment>? attachments;
  final Map<String, dynamic>? metadata;
  final String? replyToId;

  /// When the message was written.
  final DateTime createdAt;

  const PendingMessage({
    required this.clientMessageId,
    required this.roomId,
    required this.senderUserId,
    required this.content,
    this.type = MessageType.text,
    this.attachments,
    this.metadata,
    this.replyToId,
    required this.createdAt,
  });

  String get localId => '$localIdPrefix$clientMessageId';

  /// The pending message as the app shows it: `isPending == true`.
  Message toMessage() => Message(
        id: localId,
        roomId: roomId,
        senderUserId: senderUserId,
        content: content,
        type: type,
        attachments: attachments,
        metadata: metadata,
        replyToId: replyToId,
        createdAt: createdAt,
        isPending: true,
        clientMessageId: clientMessageId,
      );

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'clientMessageId': clientMessageId,
        'roomId': roomId,
        'senderUserId': senderUserId,
        'content': content,
        'type': type.name,
        if (attachments != null)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
        if (metadata != null) 'metadata': metadata,
        if (replyToId != null) 'replyToId': replyToId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
        clientMessageId: json['clientMessageId'] as String,
        roomId: json['roomId'] as String,
        senderUserId: json['senderUserId'] as String,
        content: json['content'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MessageType.text,
        ),
        attachments: (json['attachments'] as List?)
            ?.map((e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        metadata: json['metadata'] == null
            ? null
            : Map<String, dynamic>.from(json['metadata'] as Map),
        replyToId: json['replyToId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
