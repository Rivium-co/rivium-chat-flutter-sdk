/// Message content types supported by RiviumChat.
enum MessageType {
  text,
  image,
  file,
  system,
}

/// Room types for conversations.
enum RoomType {
  direct,
  group,
}

/// Participant roles within a room.
enum ParticipantRole {
  admin,
  member,
}

/// Connection states for the realtime service.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Subscription states for room channels.
enum SubscriptionStatus {
  subscribing,
  subscribed,
  unsubscribed,
}
