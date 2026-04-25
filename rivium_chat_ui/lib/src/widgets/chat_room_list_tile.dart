import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rivium_chat/rivium_chat.dart';

/// A list tile widget for displaying a chat room in a list.
/// Similar to chat list items in WhatsApp, Telegram, and Messenger.
class ChatRoomListTile extends StatelessWidget {
  /// The room to display.
  final Room room;

  /// The last message in the room.
  final Message? lastMessage;

  /// Number of unread messages.
  final int unreadCount;

  /// Whether the room is muted.
  final bool isMuted;

  /// Whether the room is pinned.
  final bool isPinned;

  /// Whether the current user is typing.
  final bool isTyping;

  /// Name of the user who is typing.
  final String? typingUserName;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Called when the tile is long pressed.
  final VoidCallback? onLongPress;

  /// Current user's ID (to determine message status).
  final String? currentUserId;

  /// Custom avatar widget.
  final Widget? avatar;

  /// Custom title widget.
  final Widget? title;

  /// Custom subtitle widget.
  final Widget? subtitle;

  /// Custom trailing widget.
  final Widget? trailing;

  /// Whether to show the online indicator.
  final bool showOnlineIndicator;

  /// Whether the other user is online (for direct chats).
  final bool isOnline;

  const ChatRoomListTile({
    super.key,
    required this.room,
    this.lastMessage,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isTyping = false,
    this.typingUserName,
    this.onTap,
    this.onLongPress,
    this.currentUserId,
    this.avatar,
    this.title,
    this.subtitle,
    this.trailing,
    this.showOnlineIndicator = true,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isPinned
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : null,
        child: Row(
          children: [
            // Avatar
            avatar ?? _buildAvatar(context),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(child: title ?? _buildTitle(context)),
                      trailing ?? _buildTrailing(context),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Subtitle row
                  Row(
                    children: [
                      Expanded(child: subtitle ?? _buildSubtitle(context)),
                      _buildBadges(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final displayName = room.name ?? 'Chat';
    // Avatar URL can be stored in room metadata
    final avatarUrl = room.metadata?['avatarUrl'] as String?;

    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: avatarUrl != null
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: avatarUrl == null
              ? Text(
                  _getInitials(displayName),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        if (showOnlineIndicator && isOnline && room.type == RoomType.direct)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            room.name ?? 'Chat',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMuted) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.notifications_off,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    if (isTyping) {
      return Text(
        typingUserName != null ? '$typingUserName is typing...' : 'typing...',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (lastMessage == null) {
      return Text(
        'No messages yet',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    final isMe = lastMessage!.senderUserId == currentUserId;
    final prefix = isMe ? 'You: ' : '';
    final content = _getMessagePreview(lastMessage!);

    return Row(
      children: [
        if (isMe) ...[
          _buildMessageStatus(context, lastMessage!),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            '$prefix$content',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: unreadCount > 0
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: unreadCount > 0 ? FontWeight.w500 : null,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getMessagePreview(Message message) {
    if (message.isDeleted) return 'Message deleted';

    switch (message.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 File';
      case MessageType.system:
        return message.content;
      case MessageType.text:
        return message.content;
    }
  }

  Widget _buildMessageStatus(BuildContext context, Message message) {
    if (message.isFailed) {
      return Icon(
        Icons.error_outline,
        size: 16,
        color: Theme.of(context).colorScheme.error,
      );
    }

    if (message.isPending) {
      return Icon(
        Icons.access_time,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    // Sent status - could be enhanced with read receipts
    return Icon(
      Icons.done_all,
      size: 16,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final time = lastMessage?.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (time != null)
          Text(
            _formatTime(time),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: unreadCount > 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: unreadCount > 0 ? FontWeight.bold : null,
                ),
          ),
      ],
    );
  }

  Widget _buildBadges(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPinned) ...[
          Icon(
            Icons.push_pin,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
        ],
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isMuted
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isMuted
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }

    final thisWeek = today.subtract(Duration(days: today.weekday - 1));
    if (messageDate.isAfter(thisWeek) || messageDate == thisWeek) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    }

    if (time.year == now.year) {
      return '${time.day}/${time.month}';
    }

    return '${time.day}/${time.month}/${time.year % 100}';
  }
}

/// A skeleton loading state for ChatRoomListTile.
class ChatRoomListTileSkeleton extends StatelessWidget {
  const ChatRoomListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar skeleton
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 40,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
