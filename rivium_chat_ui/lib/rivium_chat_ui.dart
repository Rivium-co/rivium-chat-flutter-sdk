/// RiviumChat UI - Pre-built UI widgets for RiviumChat SDK
///
/// This package provides ready-to-use Flutter widgets built on top of
/// the rivium_chat core package. All widgets use InheritedWidget for state
/// management, requiring no external state management libraries.
///
/// ## Quick Start
///
/// 1. Wrap your app with [RiviumChatProvider]:
///
/// ```dart
/// RiviumChatProvider(
///   client: riviumChatClient,
///   child: MaterialApp(...),
/// )
/// ```
///
/// 2. Use pre-built widgets:
///
/// ```dart
/// // Full chat screen
/// ChatScreen(roomId: 'room-123')
///
/// // Or build custom UI with individual widgets
/// ChatChannelProvider(
///   roomId: 'room-123',
///   child: Column(
///     children: [
///       Expanded(child: MessageList()),
///       TypingIndicator(roomId: 'room-123'),
///       ChatInputField(),
///     ],
///   ),
/// )
/// ```
///
/// ## Available Widgets
///
/// ### Core Widgets
/// - [ChatScreen] - Complete chat experience
/// - [ChatMessageBubble] - Single message display
/// - [ChatInputField] - Message input with attachments
/// - [TypingIndicator] - Shows who is typing
/// - [PresenceIndicator] - Online/offline status
/// - [UnreadBadge] - Unread message count
/// - [MessageContextMenu] - Long-press actions
///
/// ### Message Interactions
/// - [SwipeableMessage] - Swipe-to-reply gesture (like WhatsApp/Telegram)
/// - [MessageReactionPicker] - Quick emoji reactions bar
/// - [ReplyPreview] - Quoted message preview
/// - [ReadReceipts] - Message delivery & read status
///
/// ### Input Enhancements
/// - [MentionsList] - @mentions autocomplete
/// - [ChatAttachmentPicker] - Media/file picker bottom sheet
/// - [VoiceMessageRecorder] - Hold-to-record voice messages
/// - [VoiceMessagePlayer] - Audio message playback with waveform
///
/// ### Room & List Widgets
/// - [ChatRoomListTile] - Room list item (like chat list)
/// - [LinkPreview] - URL preview cards
/// - [MessageSearchBar] - Search messages with navigation
///
/// ## State Management
///
/// Access state via InheritedWidget:
///
/// ```dart
/// // Get the client
/// final client = RiviumChatScope.of(context);
///
/// // Get channel state (messages, typing, etc.)
/// final state = ChatChannelScope.of(context);
/// ```
library rivium_chat_ui;

// State management
export 'src/state/rivium_chat_scope.dart';
export 'src/state/chat_channel_scope.dart';

// Core widgets
export 'src/widgets/chat_screen.dart';
export 'src/widgets/chat_message_bubble.dart';
export 'src/widgets/chat_input_field.dart';
export 'src/widgets/typing_indicator.dart';
export 'src/widgets/presence_indicator.dart';
export 'src/widgets/unread_badge.dart';
export 'src/widgets/message_context_menu.dart';

// Message interactions
export 'src/widgets/swipeable_message.dart';
export 'src/widgets/message_reaction_picker.dart';
export 'src/widgets/reply_preview.dart';
export 'src/widgets/read_receipts.dart';

// Input enhancements
export 'src/widgets/mentions_list.dart';
export 'src/widgets/chat_attachment_picker.dart';
export 'src/widgets/voice_message_recorder.dart';

// Room & list widgets
export 'src/widgets/chat_room_list_tile.dart';
export 'src/widgets/link_preview.dart';
export 'src/widgets/message_search_bar.dart';
