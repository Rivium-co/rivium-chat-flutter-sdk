## [0.2.0] - 2026-10-30

- Added: with `queueOfflineMessages` on in the client, a message written offline shows "Waiting for network…" and turns into the sent message once it is stored (shown once); if it cannot be sent it shows Retry. Needs the `rivium_chat` release with offline sending.
- Fixed: Pin, Unpin, Edit, Delete and reactions in the message menu of `ChatScreen` did nothing; they now work, and Pin and Unpin show the new state right away.
- Fixed: a failed action shows a short message instead of an uncaught error.
- Fixed: a failed message shows a Retry button.
- Fixed: reply labels show the participant's display name (or their user id when they have none). `ChatChannelState` gains `displayNameFor()`; `ChatMessageBubble` gains `replySenderName`.
- Fixed: closing a chat screen while it was loading, or after the client was disposed, no longer throws.

## [0.1.0] - 2026-04-26

- Initial release
- Pre-built Flutter widgets for chat UI
- ChatScreen, ChatMessageBubble, ChatInputField
- TypingIndicator, PresenceIndicator, UnreadBadge
- MessageReactionPicker, MessageContextMenu
- ReadReceipts, SwipeableMessage, ReplyPreview
- ChatRoomListTile, MessageSearchBar
- ChatChannelScope state management
- Customizable theming
