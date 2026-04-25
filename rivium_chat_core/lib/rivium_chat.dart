/// RiviumChat SDK - Headless chat-as-a-service for Flutter.
///
/// This is a minimal, unopinionated SDK that works with any state management.
/// For pre-built UI widgets, use the `rivium_chat_ui` package.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:rivium_chat/rivium_chat.dart';
///
/// // Configure
/// final config = RiviumChatConfig(
///   apiKey: 'your-api-key',
///   userId: 'user-123',
/// );
///
/// // Create client
/// final client = RiviumChatClient(config);
///
/// // Connect
/// await client.connect();
///
/// // Subscribe to a room
/// await client.subscribeRoom('room-id');
///
/// // Listen to messages
/// client.onMessage.listen((message) {
///   print('New message: ${message.content}');
/// });
///
/// // Send a message
/// await client.sendMessage('room-id', content: 'Hello!');
///
/// // Cleanup
/// client.dispose();
/// ```
library rivium_chat;

// Config
export 'src/config.dart';

// Client
export 'src/rivium_chat_client.dart';

// Models
export 'src/models/enums.dart';
export 'src/models/attachment.dart';
export 'src/models/reaction.dart';
export 'src/models/message.dart';
export 'src/models/participant.dart';
export 'src/models/room.dart';
export 'src/models/unread_summary.dart';

// Events
export 'src/events/events.dart';
