import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';
import '../state/chat_channel_scope.dart';
import 'chat_message_bubble.dart';
import 'chat_input_field.dart';
import 'typing_indicator.dart';
import 'message_context_menu.dart';
import 'swipeable_message.dart';

/// A complete chat screen widget with messages, input, and interactions.
class ChatScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String? otherUserName;
  final bool readOnly;
  final FileUploader? fileUploader;
  final Widget Function(BuildContext, Message, bool isMe, bool isRead)? messageBuilder;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    this.otherUserName,
    this.readOnly = false,
    this.fileUploader,
    this.messageBuilder,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  Message? _replyingTo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near the top (since list is reversed)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ChatChannelScope.read(context).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatChannelScope(
      roomId: widget.roomId,
      child: Builder(
        builder: (context) {
          final state = ChatChannelScope.of(context);

          if (state.isLoading && state.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError && state.messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text('Failed to load messages'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: state.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Messages
              Expanded(
                child: Stack(
                  children: [
                    _buildMessageList(context, state),
                    if (state.isLoadingMore)
                      const Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Typing indicator
              TypingIndicator(roomId: widget.roomId),

              // Input
              if (!widget.readOnly)
                ChatInputField(
                  roomId: widget.roomId,
                  replyingTo: _replyingTo,
                  onCancelReply: () => setState(() => _replyingTo = null),
                  fileUploader: widget.fileUploader,
                  onMessageSent: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ChatChannelState state) {
    if (state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isMe = message.senderUserId == widget.currentUserId;
        // Only show read status for my messages when the other user has read them
        final isRead = isMe &&
            state.otherUserLastRead != null &&
            message.createdAt.isBefore(state.otherUserLastRead!);

        final Widget bubble;
        if (widget.messageBuilder != null) {
          bubble = widget.messageBuilder!(context, message, isMe, isRead);
        } else {
          bubble = ChatMessageBubble(
            message: message,
            isMe: isMe,
            otherUserName: widget.otherUserName,
            currentUserId: widget.currentUserId,
            isRead: isRead,
            onRetry: message.isFailed ? () => state.retryMessage(message) : null,
            onReactionTap: (emoji) => _toggleReaction(message, emoji),
          );
        }

        return GestureDetector(
          onLongPressStart: (details) =>
              _showContextMenu(context, message, isMe, details.globalPosition),
          child: SwipeableMessage(
            isMe: isMe,
            enabled: !message.isDeleted && !widget.readOnly,
            onReply: () => setState(() => _replyingTo = message),
            child: bubble,
          ),
        );
      },
    );
  }

  void _showContextMenu(
    BuildContext context,
    Message message,
    bool isMe,
    Offset position,
  ) {
    showMessageContextMenu(
      context: context,
      message: message,
      position: position,
      canDelete: isMe && !message.isDeleted,
      canEdit: isMe && !message.isDeleted && message.type == MessageType.text,
      canReply: !message.isDeleted,
      isPinned: message.isPinned,
      onAction: (action) => _handleContextAction(action, message),
      onReact: (emoji) => _toggleReaction(message, emoji),
    );
  }

  void _handleContextAction(MessageAction action, Message message) {
    final state = ChatChannelScope.read(context);

    switch (action) {
      case MessageAction.reply:
        setState(() => _replyingTo = message);
        break;
      case MessageAction.edit:
        _showEditDialog(message);
        break;
      case MessageAction.delete:
        _showDeleteConfirmation(message);
        break;
      case MessageAction.pin:
        state.pinMessage(message.id);
        break;
      case MessageAction.unpin:
        state.unpinMessage(message.id);
        break;
    }
  }

  void _toggleReaction(Message message, String emoji) {
    final state = ChatChannelScope.read(context);
    final hasMyReaction = message.reactions?.any(
          (r) => r.userId == widget.currentUserId && r.emoji == emoji,
        ) ??
        false;

    if (hasMyReaction) {
      state.removeReaction(message.id, emoji: emoji);
    } else {
      state.addReaction(message.id, emoji: emoji);
    }
  }

  void _showEditDialog(Message message) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                ChatChannelScope.read(context)
                    .editMessage(message.id, content: newContent);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ChatChannelScope.read(context).deleteMessage(message.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
