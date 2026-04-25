import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';

import '../models/order.dart';
import '../widgets/order_header_widget.dart';
import '../widgets/pinned_messages_sheet.dart';
import '../services/file_upload_service.dart';

/// Full-featured chat screen for an order
///
/// Demonstrates ALL RiviumChat features:
/// - ChatChannelScope for room state management
/// - ChatScreen for complete chat UI
/// - Custom message builders
/// - Typing indicators
/// - Presence indicators
/// - Reactions
/// - Message pinning
/// - File attachments
/// - Read receipts
/// - Message search
/// - Pinned messages panel
class OrderChatScreen extends StatefulWidget {
  final String roomId;
  final Order order;
  final String currentUserId;
  final String otherUserName;

  const OrderChatScreen({
    super.key,
    required this.roomId,
    required this.order,
    required this.currentUserId,
    required this.otherUserName,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  bool _showSearch = false;
  final _searchController = TextEditingController();
  List<Message>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    // Mark as read when leaving chat
    final client = RiviumChatScope.read(context);
    client.markAsRead(widget.roomId);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMessages(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final client = RiviumChatScope.read(context);
      final results = await client.searchMessages(
        widget.roomId,
        query: query,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  void _showPinnedMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PinnedMessagesSheet(
        roomId: widget.roomId,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChatChannelScope(
      roomId: widget.roomId,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _showSearch
              ? _buildSearchBar(theme)
              : _buildTitle(theme),
          actions: [
            if (!_showSearch) ...[
              // Search button
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _showSearch = true),
                tooltip: 'Search messages',
              ),
              // Pinned messages
              IconButton(
                icon: const Icon(Icons.push_pin_outlined),
                onPressed: _showPinnedMessages,
                tooltip: 'Pinned messages',
              ),
              // More options
              PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'order_details',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long),
                        SizedBox(width: 12),
                        Text('Order Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_chat',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep),
                        SizedBox(width: 12),
                        Text('Clear Chat'),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Close search
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchResults = null;
                    _searchController.clear();
                  });
                },
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            // Order info header
            OrderHeaderWidget(order: widget.order),

            // Search results or chat
            Expanded(
              child: _searchResults != null
                  ? _buildSearchResults(theme)
                  : _buildChat(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      children: [
        // Avatar with presence indicator
        Stack(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.otherUserName[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Presence indicator
            Positioned(
              right: 0,
              bottom: 0,
              child: PresenceIndicator(
                roomId: widget.roomId,
                userId: widget.order.sellerId == widget.currentUserId
                    ? widget.order.buyerId
                    : widget.order.sellerId,
                size: 10,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.otherUserName,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              // Typing indicator in title
              TypingIndicator(
                roomId: widget.roomId,
                builder: (context, typingUsers) {
                  if (typingUsers.isEmpty) {
                    return Text(
                      widget.order.orderNumber,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return Row(
                    children: [
                      Text(
                        'typing',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TypingDots(
                        color: theme.colorScheme.primary,
                        dotSize: 4,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search messages...',
        border: InputBorder.none,
        prefixIcon: _isSearching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.search),
      ),
      onChanged: (value) {
        // Debounce search
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_searchController.text == value) {
            _searchMessages(value);
          }
        });
      },
      onSubmitted: _searchMessages,
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_searchResults!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final message = _searchResults![index];
        final isMe = message.senderUserId == widget.currentUserId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatMessageBubble(
            message: message,
            isMe: isMe,
            currentUserId: widget.currentUserId,
            otherUserName: widget.otherUserName,
          ),
        );
      },
    );
  }

  Widget _buildChat() {
    // Use ChatScreen which handles everything:
    // - Message list with pagination
    // - Input field with attachments
    // - Typing indicators
    // - Read receipts
    // - Reactions
    // - Context menu (reply, edit, delete, pin)
    return ChatScreen(
      roomId: widget.roomId,
      currentUserId: widget.currentUserId,
      otherUserName: widget.otherUserName,
      fileUploader: FileUploadService.uploadFile,
      // Optional: custom message builder for e-commerce specific UI
      messageBuilder: (context, message, isMe, isRead) {
        // Check if this is a system message about order status
        if (message.type == MessageType.system) {
          return _buildSystemMessage(context, message);
        }

        // Use default bubble for regular messages
        return ChatMessageBubble(
          message: message,
          isMe: isMe,
          currentUserId: widget.currentUserId,
          otherUserName: widget.otherUserName,
          isRead: isRead,
        );
      },
    );
  }

  Widget _buildSystemMessage(BuildContext context, Message message) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'order_details':
        _showOrderDetails();
        break;
      case 'clear_chat':
        _confirmClearChat();
        break;
    }
  }

  void _showOrderDetails() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _OrderDetailsSheet(order: widget.order),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text(
          'This will delete all messages in this chat. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, implement chat clearing
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final Order order;

  const _OrderDetailsSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order Details',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Product info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  order.productImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${order.quantity}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: \$${order.total.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Order info rows
          _InfoRow(label: 'Order Number', value: order.orderNumber),
          _InfoRow(label: 'Status', value: order.statusText),
          _InfoRow(label: 'Seller', value: order.sellerName),
          _InfoRow(label: 'Buyer', value: order.buyerName),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
