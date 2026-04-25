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
  rivium_chat: ^0.1.0
  rivium_chat_ui: ^0.1.0
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
