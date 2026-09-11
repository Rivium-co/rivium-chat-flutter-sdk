import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';

void main() {
  test('parses the exact payloads that went missing on mobile', () {
    // Real wire samples captured from the Rivium chat server via the
    // Node SDK (IDs replaced with placeholders) — the mobile client showed some of
    // these on-screen and dropped others. If Message.fromJson throws on
    // any of these, we've found the culprit.
    final payloads = <String>[
      // 💀💀 — reply to a pinned parent (nested Message with pinnedAt).
      '{"id":"00000000-0000-4000-8000-000000000011","roomId":"00000000-0000-4000-8000-000000000001","senderUserId":"user-a","type":"text","content":"skull","attachments":null,"metadata":null,"replyToId":"00000000-0000-4000-8000-000000000012","isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":false,"pinnedAt":null,"pinnedBy":null,"createdAt":"2026-08-02T21:56:07.084Z","reactions":[],"replyTo":{"id":"00000000-0000-4000-8000-000000000012","roomId":"00000000-0000-4000-8000-000000000001","senderUserId":"user-b","type":"text","content":"dorosteh","attachments":null,"metadata":null,"replyToId":null,"isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":true,"pinnedAt":"2026-08-02T21:55:58.229Z","pinnedBy":"user-a","createdAt":"2026-08-02T21:54:22.105Z"}}',
      // ریپلای کار نمیکنه — plain, no replyTo.
      '{"id":"00000000-0000-4000-8000-000000000013","roomId":"00000000-0000-4000-8000-000000000001","senderUserId":"user-a","type":"text","content":"replay-nemikone","attachments":null,"metadata":null,"replyToId":null,"isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":false,"pinnedAt":null,"pinnedBy":null,"createdAt":"2026-08-02T21:56:39.859Z","reactions":[],"replyTo":null}',
      // نتم قطع شد — plain, no replyTo.
      '{"id":"00000000-0000-4000-8000-000000000014","roomId":"00000000-0000-4000-8000-000000000001","senderUserId":"user-a","type":"text","content":"netam-ghat-shod","attachments":null,"metadata":null,"replyToId":null,"isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":false,"pinnedAt":null,"pinnedBy":null,"createdAt":"2026-08-02T21:58:07.500Z","reactions":[],"replyTo":null}',
    ];
    for (var i = 0; i < payloads.length; i++) {
      final json = jsonDecode(payloads[i]) as Map<String, dynamic>;
      final m = Message.fromJson(json);
      // ignore: avoid_print
      print(
        'parsed [$i] id=${m.id.substring(0, 8)} content=${m.content} '
        'replyTo=${m.replyTo?.content ?? "-"}',
      );
    }
  });
}
