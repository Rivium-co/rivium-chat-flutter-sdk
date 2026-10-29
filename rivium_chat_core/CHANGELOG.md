## [0.2.0] - 2026-10-30

- Added: offline sending, off by default. With `RiviumChatConfig(queueOfflineMessages: true)`, a message that cannot be sent because of the network (no network, timeout, server busy, `tokenProvider` unreachable) is kept and sent when the connection is back, in the order written and never twice. `sendMessage()` then returns it as a pending message (`isPending == true`, id `local_<clientMessageId>`) instead of throwing. Errors the server answers (not a member, invalid message, plan limit) still throw. Without the option nothing changes.
- Added: `onMessageSent` (a queued message was stored) and `onMessageFailed` (it left the queue unsent, `reason` `'expired'` after 24 hours or `'rejected'` by the server), plus `getPendingMessages()`, `retryPendingMessages()`, `cancelPendingMessage()` and `clearPendingMessages()`.
- Added: the queue is kept in memory by default; pass `outboxStore` (implement `OutboxStore` with the storage your app uses) to keep it across app restarts. No new dependency.
- Added: `Message.clientMessageId`.
- Fixed: `searchMessages()` no longer fails; it reads the search results the API returns.
- Fixed: `getMentions()` no longer fails; it returns the mentioned messages.
- Fixed: `getRoomByExternalId()` works with external ids that contain characters such as `/`, `#` or spaces.
- Fixed: `connect()` throws an `ArgumentError` when `apiKey` or `userId` is empty, instead of every request failing later. Creating the client still never throws, so a `RiviumChatScope` built before the user is known reports the error through `onError`.
- Fixed: when `tokenProvider` fails during `connect()`, `onAuthError` now reports `token_provider_failed`, as it already did for other calls.
- Fixed: `publishTyping()` is throttled per room, so typing in one room no longer hides typing in another for 2 seconds.
- Fixed: `disconnect()` and `dispose()` with rooms open no longer leave uncaught errors (`ClientDisconnectedError`, "Cannot add new events after calling close") that an app's error reporting would record on every sign-out.
- Added: `searchMessagesWithTotal()` returns a `SearchResult` with the matching `messages`, the `total` number of matches and `hasMore`. `searchMessages()` is unchanged.
- Fixed: a room subscription the server refuses (for example "Not a participant in this room") is now reported on `onRecoveryFailed` for the room, and the `error` event on `onSubscriptionState` carries the server's `code` and `reason`.
- Fixed: calling `disconnect()` or `dispose()` while `connect()` was still fetching its token no longer opens a connection afterwards.

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
