# RiviumChat Flutter E-commerce Example

A comprehensive example demonstrating how to integrate RiviumChat SDK into an e-commerce application for buyer-seller communication.

## Features Demonstrated

This example showcases **all RiviumChat SDK features** in a real-world e-commerce scenario:

### Core SDK Features (`rivium_chat`)
- **Room Management**
  - `findOrCreateRoom` - Create/get chat room for each order
  - `listRooms` - List all conversations
  - `getRoom` - Get room details
  - `addParticipant` - Add users to rooms

- **Messaging**
  - `sendMessage` - Send text, images, files
  - `getMessages` - Paginated message history
  - `editMessage` - Edit sent messages
  - `deleteMessage` - Delete messages
  - `searchMessages` - Search within conversations

- **Reactions**
  - `addReaction` - Add emoji reactions
  - `removeReaction` - Remove reactions
  - `getReactions` - Get all reactions

- **Message Pinning**
  - `pinMessage` - Pin important messages
  - `unpinMessage` - Unpin messages
  - `getPinnedMessages` - List pinned messages

- **Read Receipts & Presence**
  - `markAsRead` - Mark messages as read
  - `getUnreadSummary` - Get unread counts
  - `getRoomPresence` - Check who's online
  - `publishTyping` - Send typing indicator

- **Realtime Events**
  - `onMessage` - New message stream
  - `onReadReceipt` - Read receipt stream
  - `onTypingEvent` - Typing indicator stream
  - `onPresenceChange` - Online/offline stream
  - `onReactionEvent` - Reaction changes
  - `onMessageEdited` - Edit notifications
  - `onMessagePinChanged` - Pin/unpin events

### UI Kit Features (`rivium_chat_ui`)
- **State Management**
  - `RiviumChatScope` - Root provider with auto-connect
  - `ChatChannelScope` - Room-specific state

- **Complete Chat UI**
  - `ChatScreen` - Full chat experience
  - `ChatMessageBubble` - Message bubbles with reactions, replies
  - `ChatInputField` - Input with emoji picker, attachments

- **Indicators**
  - `TypingIndicator` - Animated typing dots
  - `PresenceIndicator` - Online/offline status
  - `UnreadBadge` - Unread count badges

- **Interactions**
  - Swipe-to-reply
  - Long-press context menu
  - Quick emoji reactions
  - Full-screen image viewer

## Project Structure

```
lib/
├── main.dart                    # App entry, RiviumChatScope setup
├── models/
│   └── order.dart               # Order model with mock data
├── screens/
│   ├── login_screen.dart        # Demo user selection
│   ├── orders_screen.dart       # Order list with unread badges
│   └── order_chat_screen.dart   # Full chat with all features
├── widgets/
│   ├── order_header_widget.dart # Order info in chat
│   └── pinned_messages_sheet.dart # Pinned messages panel
└── services/
    └── file_upload_service.dart # File upload example
```

## Getting Started

### 1. Install Dependencies

```bash
cd examples/flutter_ecommerce
flutter pub get
```

### 2. Configure API Key

Open `lib/main.dart` and replace the API key:

```dart
static const String _apiKey = 'YOUR_RIVIUM_CHAT_API_KEY';
```

Get your API key from the [AuthLeap Dashboard](https://dashboard.authleap.com):
1. Go to Organizations → Your Org → Projects
2. Enable RiviumChat for your project
3. Copy the API key

### 3. Configure File Uploads (Optional)

Open `lib/services/file_upload_service.dart` and implement your storage service:

```dart
// Example with Firebase Storage:
final ref = FirebaseStorage.instance.ref('chat-attachments/$fileName');
await ref.putFile(file);
final url = await ref.getDownloadURL();

return FileUploadResult(
  url: url,
  mimeType: mimeType,
  name: fileName,
  size: fileSize,
);
```

### 4. Run the App

```bash
flutter run
```

## Usage Scenarios

### Scenario 1: Buyer-Seller Chat

1. Login as a **Buyer** (e.g., Alice Johnson)
2. See your orders list with unread message counts
3. Tap an order to open the chat
4. Send messages, images, files to the seller
5. See typing indicators when seller is typing
6. React to messages with emojis
7. Pin important messages (e.g., tracking info)

### Scenario 2: Multi-Device Testing

1. Run the app on two devices/simulators
2. Login as **Buyer** on one, **Seller** on other
3. See real-time message delivery
4. Watch typing indicators appear
5. See read receipts update
6. Test presence indicators

### Scenario 3: Rich Messaging

1. Send a message and swipe to reply
2. Long-press a message for context menu
3. Try edit and delete
4. Send an image attachment
5. Pin a message and view pinned panel
6. Search for messages

## Code Examples

### Initialize RiviumChat

```dart
// In main.dart - wrap your app with RiviumChatScope
RiviumChatScope(
  config: RiviumChatConfig(
    apiKey: 'YOUR_API_KEY',
    userId: currentUser.id,
    userInfo: {'displayName': currentUser.name},
    fileUploader: FileUploadService.uploadFile,
  ),
  autoConnect: true,
  onConnected: () => print('Connected!'),
  onError: (e) => print('Error: $e'),
  child: MyApp(),
)
```

### Create/Get Room for Order

```dart
final client = RiviumChatScope.read(context);

final room = await client.findOrCreateRoom(
  externalId: 'order-${order.id}',
  type: RoomType.direct,
  name: 'Order ${order.orderNumber}',
  participants: [
    {'externalUserId': buyerId, 'displayName': buyerName, 'locale': 'en'},
    {'externalUserId': sellerId, 'displayName': sellerName, 'locale': 'en'},
  ],
  metadata: {
    'orderId': order.id,
    'pushVariables': {'orderNumber': order.orderNumber},
    'pushData': {'deepLink': 'myapp://orders/${order.id}/chat'},
  },
);
```

### Use ChatScreen

```dart
// Complete chat UI with one widget
ChatScreen(
  roomId: room.id,
  currentUserId: currentUserId,
  otherUserName: otherUserName,
  fileUploader: FileUploadService.uploadFile,
)
```

### Custom Chat UI

```dart
// Build your own UI with individual widgets
ChatChannelScope(
  roomId: room.id,
  child: Column(
    children: [
      // Custom header with presence
      Row(
        children: [
          Text(otherUserName),
          PresenceIndicator(roomId: room.id, userId: otherUserId),
        ],
      ),

      // Message list
      Expanded(
        child: Builder(
          builder: (context) {
            final state = ChatChannelScope.of(context);
            return ListView.builder(
              itemCount: state.messages.length,
              itemBuilder: (context, i) {
                final msg = state.messages[i];
                return ChatMessageBubble(
                  message: msg,
                  isMe: msg.senderUserId == currentUserId,
                );
              },
            );
          },
        ),
      ),

      // Typing indicator
      TypingIndicator(roomId: room.id),

      // Input field
      ChatInputField(roomId: room.id),
    ],
  ),
)
```

### Listen to Events

```dart
final client = RiviumChatScope.read(context);

// New messages
client.onMessage.listen((message) {
  print('New message: ${message.content}');
});

// Typing
client.onTypingEvent.listen((event) {
  print('${event.userId} is ${event.isTyping ? "typing" : "stopped"}');
});

// Presence
client.onPresenceChange.listen((event) {
  print('${event.userId} is ${event.isOnline ? "online" : "offline"}');
});

// Reactions
client.onReactionEvent.listen((event) {
  print('${event.userId} ${event.added ? "added" : "removed"} ${event.emoji}');
});
```

## Push Notifications

RiviumChat automatically sends push notifications to offline users via Pushino. Configure templates in the AuthLeap dashboard:

1. Create a Pushino template with variables:
   - `{{senderName}}` - Who sent the message
   - `{{messagePreview}}` - First 100 chars
   - `{{orderNumber}}` - From room metadata

2. Set the template ID in RiviumChat settings

3. Pass `pushVariables` in room/message metadata for custom data

## Troubleshooting

### Connection Issues
- Check API key is correct
- Ensure device has internet
- Check AuthLeap dashboard for project status

### Messages Not Appearing
- Verify `subscribeRoom` was called (automatic with ChatScreen)
- Check WebSocket connection status
- Look for errors in `onError` callback

### File Uploads Failing
- Implement actual upload in `FileUploadService`
- Check file size limits (default 20MB)
- Verify storage service credentials

## Learn More

- [RiviumChat Documentation](https://docs.rivium_chat.com)
- [Flutter SDK Reference](https://pub.dev/packages/rivium_chat)
- [AuthLeap Dashboard](https://dashboard.authleap.com)
