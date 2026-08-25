import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivium_chat/rivium_chat.dart';

void main() {
  test('parses the exact payloads that went missing on mobile', () {
    // Real wire samples captured from the Rivium chat server via the
    // Node SDK for room 2667f50f-... — the mobile client showed some of
    // these on-screen and dropped others. If Message.fromJson throws on
    // any of these, we've found the culprit.
    final payloads = <String>[
      // 💀💀 — reply to a pinned parent (nested Message with pinnedAt).
      '{"id":"f606513c-db4e-4058-9aae-ad35ac1d5e2e","roomId":"2667f50f-9adb-4900-9c5f-d394d5142dde","senderUserId":"6a69d5fb023d3c0ba7298093","type":"text","content":"skull","attachments":null,"metadata":null,"replyToId":"efe8e9e6-b9a8-4279-a24d-00f54d404fb2","isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":false,"pinnedAt":null,"pinnedBy":null,"createdAt":"2026-08-02T21:56:07.084Z","reactions":[],"replyTo":{"id":"efe8e9e6-b9a8-4279-a24d-00f54d404fb2","roomId":"2667f50f-9adb-4900-9c5f-d394d5142dde","senderUserId":"6a69601d023d3c0ba729663a","type":"text","content":"dorosteh","attachments":null,"metadata":null,"replyToId":null,"isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":true,"pinnedAt":"2026-08-02T21:55:58.229Z","pinnedBy":"6a69d5fb023d3c0ba7298093","createdAt":"2026-08-02T21:54:22.105Z"}}',
      // ریپلای کار نمیکنه — plain, no replyTo.
      '{"id":"e9fa77e0-f953-4571-943f-8f5f31943df4","roomId":"2667f50f-9adb-4900-9c5f-d394d5142dde","senderUserId":"6a69d5fb023d3c0ba7298093","type":"text","content":"replay-nemikone","attachments":null,"metadata":null,"replyToId":null,"isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":false,"pinnedAt":null,"pinnedBy":null,"createdAt":"2026-08-02T21:56:39.859Z","reactions":[],"replyTo":null}',
      // نتم قطع شد — plain, no replyTo.
      '{"id":"5578c981-e8a7-469c-ba15-a4b67e73b0fa","roomId":"2667f50f-9adb-4900-9c5f-d394d5142dde","senderUserId":"6a69d5fb023d3c0ba7298093","type":"text","content":"netam-ghat-shod","attachments":null,"metadata":null,"replyToId":null,"isDeleted":false,"isEdited":false,"editedAt":null,"editHistory":null,"isPinned":false,"pinnedAt":null,"pinnedBy":null,"createdAt":"2026-08-02T21:58:07.500Z","reactions":[],"replyTo":null}',
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
