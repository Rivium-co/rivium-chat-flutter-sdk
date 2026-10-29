# RiviumChat Flutter SDK

Real-time messaging SDK for Flutter. Add chat to your app with pre-built UI widgets, real-time messaging, read receipts, typing indicators, reactions, and push notifications.

## Features

- Real-time messaging via WebSocket (<50ms latency)
- Pre-built Flutter widgets (chat screen, message bubbles, input field, typing indicator, etc.)
- Read receipts with delivery status (sent, delivered, read)
- Emoji reactions and message pinning
- Typing and presence indicators
- Threaded replies and swipe-to-reply
- File and image sharing with inline previews
- Full-text message search
- Unread message counts
- Push notifications via [Rivium Push](https://rivium.co/cloud/rivium-push) for offline users
- Customizable theming
- Works with any state management solution
- Pure Dart core SDK — no native platform code

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  rivium_chat: ^0.2.0
  rivium_chat_ui: ^0.2.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the Client

```dart
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';

final client = RiviumChatClient(
  config: RiviumChatConfig(
    apiKey: 'your_api_key',
    userId: 'user-123',
    userInfo: {'displayName': 'John'},
  ),
);

await client.connect();
```

### 2. Create or Join a Room

```dart
final room = await client.findOrCreateRoom(
  externalId: 'order-123',
  participants: [
    {'externalUserId': 'user-123', 'displayName': 'John', 'role': 'member'},
    {'externalUserId': 'user-456', 'displayName': 'Jane', 'role': 'member'},
  ],
);
```

### 3. Send Messages

```dart
final message = await client.sendMessage(room.id, content: 'Hello!');
```

### 4. Listen for Real-Time Events

```dart
// New messages
client.onMessage.listen((message) {
  print('New message: ${message.content}');
});

// Typing indicators
client.onTypingEvent.listen((event) {
  print('${event.userId} is typing: ${event.isTyping}');
});

// Presence (online/offline)
client.onPresenceChange.listen((event) {
  print('${event.userId} is online: ${event.isOnline}');
});

// Read receipts
client.onReadReceipt.listen((event) {
  print('${event.userId} read messages at ${event.readAt}');
});
```

### 5. Mark Messages as Read

```dart
await client.markAsRead(room.id);
```

### 6. Search Messages

```dart
final result = await client.searchMessagesWithTotal(room.id, query: 'Order #1001');
print('${result.total} matches');
for (final message in result.messages) {
  print(message.content);
}
```

`total` counts every match, not only this page; `hasMore` says whether another page follows (pass `limit` and `offset` to page). `searchMessages()` still returns only the list.

## Sending while offline

By default `sendMessage` throws when there is no network. Turn on the offline queue to keep such messages and send them when the connection is back, in the order written and never twice:

```dart
final client = RiviumChatClient(const RiviumChatConfig(
  apiKey: 'rv_live_demo_app',
  userId: 'user-42',
  queueOfflineMessages: true,
));

final message = await client.sendMessage(roomId, content: 'Order #1001 is ready');
if (message.isPending) {
  // Queued: shown as waiting, sent when the network is back
}

client.onMessageSent.listen((event) {
  // event.localId (the pending id) -> event.message (the stored message)
});
client.onMessageFailed.listen((event) {
  // event.reason: 'expired' (waited 24 hours) or 'rejected' (refused by the server)
});
```

- Only network failures are queued (no network, timeout, a failing `tokenProvider`, 5xx, 408, 429). Errors the server answers, such as not a member of the room or an invalid message, still throw.
- A queued message has `isPending == true`, the id `local_<clientMessageId>` and `clientMessageId`. The stored message (and its live `onMessage` event) carries the same `clientMessageId`, so you can replace the pending copy.
- The queue is sent when the realtime connection comes back, and with `retryPendingMessages()`. `getPendingMessages(roomId: ...)` lists what waits; `cancelPendingMessage(localId)` removes one (a message already being sent cannot be recalled). Queued messages of another user on the same device are never sent.
- Attachments must already be uploaded (URLs); uploads themselves are not queued.

The queue lives in memory. To keep it across app restarts, pass an `outboxStore` built on the storage your app already uses, for example shared_preferences:

```dart
class PrefsOutboxStore implements OutboxStore {
  PrefsOutboxStore(this.key); // one key per project and user, e.g. 'chat_outbox_user-42'
  final String key;

  @override
  Future<List<PendingMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null) return [];
    return (jsonDecode(text) as List)
        .map((e) => PendingMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> save(List<PendingMessage> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items.map((p) => p.toJson()).toList()));
  }
}

RiviumChatConfig(
  apiKey: 'rv_live_demo_app',
  userId: 'user-42',
  queueOfflineMessages: true,
  outboxStore: PrefsOutboxStore('chat_outbox_user-42'),
);
```

Call `client.clearPendingMessages()` on sign-out when another user may sign in on the device. The UI kit's chat screen shows queued messages as "Waiting for network…".

## Packages

| Package | Description |
|---------|-------------|
| `rivium_chat` | Core SDK — API client, real-time messaging, models |
| `rivium_chat_ui` | Pre-built Flutter widgets with theming |

## UI Widgets

`rivium_chat_ui` includes ready-to-use Flutter widgets:

- `ChatScreen` - Full chat screen with messages, input, and state management
- `ChatMessageBubble` - Message bubble with read receipts, reactions, and reply preview
- `ChatInputField` - Text input with attachment and typing indicator support
- `TypingIndicator` - Animated typing dots
- `PresenceIndicator` - Online/offline status dot
- `UnreadBadge` - Unread message count badge
- `MessageReactionPicker` - Emoji reaction selector
- `ChatRoomListTile` - Room list item with last message preview
- `ReadReceipts` - Delivery status indicators (sent, delivered, read)
- `SwipeableMessage` - Swipe-to-reply gesture
- `MessageSearchBar` - Full-text message search

## Example App

The `flutter_ecommerce/` directory contains a complete e-commerce chat example demonstrating:

- Buyer/seller chat for order support
- Real-time messaging with read receipts
- Typing and presence indicators
- Emoji reactions and message pinning
- Push notifications (via Rivium Push)
- Unread message badges
- Message pagination
- Reply to messages

## Push Notifications

RiviumChat integrates with [Rivium Push](https://rivium.co/cloud/rivium-push) for offline push notifications:

```dart
import 'package:rivium_push/rivium_push.dart';

RiviumPush.init(config: RiviumPushConfig(apiKey: 'your_api_key'));
RiviumPush.register(userId: 'user-123');
```

## Links

- [Rivium Chat](https://rivium.co/cloud/rivium-chat) - Learn more about Rivium Chat
- [Documentation](https://rivium.co/cloud/rivium-chat/docs/quick-start) - Full documentation and guides
- [Rivium Console](https://console.rivium.co) - Manage your chat rooms

## License

MIT
