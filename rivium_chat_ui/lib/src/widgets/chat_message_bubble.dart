import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rivium_chat/rivium_chat.dart';

/// A message bubble widget for displaying chat messages.
class ChatMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final String? otherUserName;
  final String? currentUserId;
  final VoidCallback? onRetry;
  final void Function(String emoji)? onReactionTap;
  final bool isRead;
  final Map<String, String>? mentionDisplayNames;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.otherUserName,
    this.currentUserId,
    this.onRetry,
    this.onReactionTap,
    this.isRead = false,
    this.mentionDisplayNames,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return _buildSystemMessage(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) _buildAvatar(context),
          if (!isMe && showAvatar) const SizedBox(width: 8),
          Flexible(child: _buildBubble(context)),
          if (isMe) const SizedBox(width: 4),
          if (isMe) _buildStatusIcon(context),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        (otherUserName ?? '?')[0].toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Reply preview
        if (message.replyTo != null) _buildReplyPreview(context),

        // Main bubble
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: message.isDeleted
                ? theme.colorScheme.surfaceContainerHighest
                : bubbleColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: message.isDeleted
              ? _buildDeletedContent(context)
              : _buildContent(context, textColor),
        ),

        // Reactions
        if (message.reactions?.isNotEmpty ?? false)
          _buildReactions(context),

        // Metadata (time, edited, pinned)
        _buildMetadata(context),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final reply = message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        reply.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildDeletedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'Message deleted',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.file:
        return _buildFileContent(context, textColor);
      default:
        return _buildTextContent(context, textColor);
    }
  }

  Widget _buildTextContent(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _buildTextWithMentions(context, textColor),
    );
  }

  Widget _buildTextWithMentions(BuildContext context, Color textColor) {
    final content = message.content;
    final mentionPattern = RegExp(r'@(\w+)');

    if (!mentionPattern.hasMatch(content) || mentionDisplayNames == null) {
      return Text(content, style: TextStyle(color: textColor));
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in mentionPattern.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      final userId = match.group(1)!;
      final displayName = mentionDisplayNames?[userId] ?? '@$userId';

      spans.add(TextSpan(
        text: '@$displayName',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isMe
              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9)
              : Theme.of(context).colorScheme.primary,
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor),
        children: spans,
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final attachment = message.attachments?.firstOrNull;
    if (attachment == null) {
      return _buildTextContent(
          context, Theme.of(context).colorScheme.onSurface);
    }

    // Thumbnail size constraints - small preview that expands on tap
    const double maxWidth = 180;
    const double maxHeight = 180;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, attachment.url),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            minWidth: 100,
            minHeight: 80,
          ),
          child: CachedNetworkImage(
            imageUrl: attachment.url,
            placeholder: (context, url) => Container(
              width: 150,
              height: 120,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 150,
              height: 100,
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Icon(Icons.error),
            ),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: url,
          fileName: message.attachments?.firstOrNull?.name,
        ),
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, Color textColor) {
    final attachment = message.attachments?.firstOrNull;
    if (attachment == null) {
      return _buildTextContent(context, textColor);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, color: textColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name ?? 'File',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attachment.size != null)
                  Text(
                    _formatFileSize(attachment.size!),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildReactions(BuildContext context) {
    final grouped = <String, int>{};
    for (final reaction in message.reactions!) {
      grouped[reaction.emoji] = (grouped[reaction.emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: grouped.entries.map((entry) {
          return GestureDetector(
            onTap: () => onReactionTap?.call(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isPinned) ...[
            Icon(
              Icons.push_pin,
              size: 12,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            _formatTime(message.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (message.isEdited) ...[
            const SizedBox(width: 4),
            Text(
              '(edited)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusIcon(BuildContext context) {
    if (message.isFailed) {
      return GestureDetector(
        onTap: onRetry,
        child: Icon(
          Icons.error_outline,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }

    if (message.isPending) {
      return Icon(
        Icons.access_time,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    if (isRead) {
      return Icon(
        Icons.done_all,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    return Icon(
      Icons.done,
      size: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

/// Full screen image viewer with zoom and download support.
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? fileName;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.fileName,
  });

  /// Shows the image viewer in a new route.
  static void show(BuildContext context,
      {required String imageUrl, String? fileName}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          fileName: fileName,
        ),
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isDownloading = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    try {
      final uri = Uri.parse(widget.imageUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName ?? 'Image',
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.fit_screen, color: Colors.white),
            tooltip: 'Reset zoom',
          ),
          IconButton(
            onPressed: _isDownloading ? null : _downloadImage,
            icon: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download',
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTap: _resetZoom,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
