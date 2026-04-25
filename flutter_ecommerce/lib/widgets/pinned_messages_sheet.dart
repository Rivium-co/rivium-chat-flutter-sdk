import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';

/// Bottom sheet showing all pinned messages in a room
///
/// Demonstrates:
/// - getPinnedMessages API
/// - unpinMessage API
/// - Custom message display
class PinnedMessagesSheet extends StatefulWidget {
  final String roomId;
  final String currentUserId;

  const PinnedMessagesSheet({
    super.key,
    required this.roomId,
    required this.currentUserId,
  });

  @override
  State<PinnedMessagesSheet> createState() => _PinnedMessagesSheetState();
}

class _PinnedMessagesSheetState extends State<PinnedMessagesSheet> {
  List<Message>? _pinnedMessages;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPinnedMessages();
  }

  Future<void> _loadPinnedMessages() async {
    try {
      final client = RiviumChatScope.read(context);
      final messages = await client.getPinnedMessages(widget.roomId);

      if (mounted) {
        setState(() {
          _pinnedMessages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unpinMessage(String messageId) async {
    try {
      final client = RiviumChatScope.read(context);
      await client.unpinMessage(messageId);

      // Remove from local list
      setState(() {
        _pinnedMessages?.removeWhere((m) => m.id == messageId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unpinned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unpin: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pinned Messages',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (_pinnedMessages != null)
                      Text(
                        '${_pinnedMessages!.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _buildContent(theme, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ThemeData theme, ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load pinned messages',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadPinnedMessages();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pinnedMessages == null || _pinnedMessages!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.push_pin_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No pinned messages',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Long-press any message and select "Pin" to pin it here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _pinnedMessages!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = _pinnedMessages![index];
        final isMe = message.senderUserId == widget.currentUserId;

        return _PinnedMessageCard(
          message: message,
          isMe: isMe,
          onUnpin: () => _unpinMessage(message.id),
        );
      },
    );
  }
}

class _PinnedMessageCard extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onUnpin;

  const _PinnedMessageCard({
    required this.message,
    required this.isMe,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  child: Text(
                    isMe ? 'You' : message.senderUserId[0].toUpperCase(),
                    style: TextStyle(
                      color: isMe
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMe ? 'You' : message.senderUserId,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.push_pin_outlined),
                  iconSize: 18,
                  onPressed: onUnpin,
                  tooltip: 'Unpin',
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Message content
            Text(
              message.content,
              style: theme.textTheme.bodyMedium,
            ),

            // Attachments preview
            if (message.attachments != null && message.attachments!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.attachment,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${message.attachments!.length} attachment(s)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            // Pinned info
            if (message.pinnedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Pinned on ${_formatDate(message.pinnedAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
