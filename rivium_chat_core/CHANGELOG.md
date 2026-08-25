## [0.1.1] - 2026-08-03

- Fixed silent drop of realtime frames when a payload failed to parse.
- Added `RiviumChatClient.onParseError` for observing parse failures.

## [0.1.0] - 2026-04-26

- Initial release
- Real-time messaging via Centrifugo WebSocket
- Room management (create, find, list)
- Message operations (send, edit, delete, search)
- Read receipts and unread counts
- Typing indicators with 2-second throttle
- Presence tracking with initial query on subscribe
- Emoji reactions and message pinning
- observeRoom for chat-only subscriptions
- leaveRoom for leaving presence/typing without disconnecting chat
- File attachments support
