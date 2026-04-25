import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';

/// A widget that displays a reply preview (quoted message).
/// Used both in message bubbles and in the input area when replying.
class ReplyPreview extends StatelessWidget {
  /// The message being replied to.
  final Message message;

  /// The display name of the message sender.
  final String? senderName;

  /// Whether this is displayed in a message bubble (vs input area).
  final bool inBubble;

  /// Whether this is in a message from the current user.
  final bool isMe;

  /// Called when the preview is tapped (to scroll to original message).
  final VoidCallback? onTap;

  /// Called when the close button is tapped (in input area).
  final VoidCallback? onClose;

  /// The accent color for the left border.
  final Color? accentColor;

  /// Maximum lines for the preview text.
  final int maxLines;

  const ReplyPreview({
    super.key,
    required this.message,
    this.senderName,
    this.inBubble = true,
    this.isMe = false,
    this.onTap,
    this.onClose,
    this.accentColor,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = accentColor ??
        (isMe && inBubble
            ? Colors.white.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.primary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: inBubble ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sender name
                  if (senderName != null)
                    Text(
                      senderName!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: borderColor,
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Message content preview
                  const SizedBox(height: 2),
                  _buildContentPreview(context),
                ],
              ),
            ),

            // Attachment thumbnail
            if (_hasMediaAttachment) ...[
              const SizedBox(width: 8),
              _buildAttachmentThumbnail(context),
            ],

            // Close button (for input area)
            if (onClose != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    if (inBubble) {
      return isMe
          ? Colors.white.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  bool get _hasMediaAttachment {
    return message.type == MessageType.image &&
        message.attachments?.isNotEmpty == true;
  }

  Widget _buildContentPreview(BuildContext context) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 14,
            color: _getTextColor(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Message deleted',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getTextColor(context),
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      );
    }

    final content = _getContentText();
    final icon = _getContentIcon();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: _getTextColor(context)),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getTextColor(context),
                ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getContentText() {
    switch (message.type) {
      case MessageType.image:
        return 'Photo';
      case MessageType.file:
        return message.attachments?.firstOrNull?.name ?? 'File';
      case MessageType.system:
        return message.content;
      case MessageType.text:
        return message.content;
    }
  }

  IconData? _getContentIcon() {
    switch (message.type) {
      case MessageType.image:
        return Icons.photo;
      case MessageType.file:
        return Icons.attach_file;
      default:
        return null;
    }
  }

  Color _getTextColor(BuildContext context) {
    if (isMe && inBubble) {
      return Colors.white.withValues(alpha: 0.8);
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _buildAttachmentThumbnail(BuildContext context) {
    final attachment = message.attachments?.firstOrNull;
    if (attachment == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        attachment.url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 40,
          height: 40,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image, size: 20),
        ),
      ),
    );
  }
}

/// A compact reply indicator shown in the input area.
class ReplyInputPreview extends StatelessWidget {
  /// The message being replied to.
  final Message message;

  /// The display name of the message sender.
  final String? senderName;

  /// Called when the close button is tapped.
  final VoidCallback onClose;

  /// Called when the preview is tapped.
  final VoidCallback? onTap;

  const ReplyInputPreview({
    super.key,
    required this.message,
    required this.onClose,
    this.senderName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Replying to ${senderName ?? 'message'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.isDeleted
                        ? 'Message deleted'
                        : _getPreviewText(message),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPreviewText(Message message) {
    switch (message.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 ${message.attachments?.firstOrNull?.name ?? 'File'}';
      default:
        return message.content;
    }
  }
}

/// Thread indicator showing reply count.
class ThreadIndicator extends StatelessWidget {
  /// Number of replies in the thread.
  final int replyCount;

  /// Avatars of users who replied.
  final List<String>? replyAvatars;

  /// Called when tapped to expand the thread.
  final VoidCallback? onTap;

  /// Maximum avatars to show.
  final int maxAvatars;

  const ThreadIndicator({
    super.key,
    required this.replyCount,
    this.replyAvatars,
    this.onTap,
    this.maxAvatars = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (replyCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply avatars
            if (replyAvatars != null && replyAvatars!.isNotEmpty) ...[
              SizedBox(
                width: 16.0 +
                    (replyAvatars!.take(maxAvatars).length - 1) * 10.0,
                height: 16,
                child: Stack(
                  children: replyAvatars!
                      .take(maxAvatars)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    return Positioned(
                      left: entry.key * 10.0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(entry.value),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Reply count
            Text(
              '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
