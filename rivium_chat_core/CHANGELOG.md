## [0.1.5] - 2026-10-05

- Added: requests send an `X-Rivium-SDK` header (`flutter/<version>`); `riviumChatSdkName` and `riviumChatSdkVersion` are exported.

## [0.1.4] - 2026-09-26

- Added: `lastMessage` and `unreadCount` on `Room`. A chat list can show the
  latest message and an unread badge from `listRooms()` alone, with no extra
  calls.

## [0.1.3] - 2026-09-11

- Added: `tokenProvider` for secure user identity. Tokens are refreshed automatically before they expire and after an expired-token response.
- Added: `onAuthError` stream for identity errors a refresh cannot fix.

## [0.1.2] - 2026-09-09

- Fixed: subscribing to a room could throw "Subscription to a channel already exists" after leaving and rejoining it.
- Fixed: `subscribeRoom` could report success while a channel had not subscribed, leaving the room without live updates.
- Fixed: one channel failing no longer discards the ones that succeeded.
- Added: `isRoomSubscribed()` and `subscribedChannelsFor()` to check subscription state.
- Added: `reconnect()` to recover a stale connection.
- Added: timeouts on REST calls.

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
