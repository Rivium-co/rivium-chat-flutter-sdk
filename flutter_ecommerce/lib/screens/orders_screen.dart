import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import 'order_chat_screen.dart';

/// Main screen showing list of orders with chat integration
///
/// Demonstrates:
/// - RiviumChatScope.of(context) to access the client
/// - UnreadBadge for showing unread counts
/// - Room creation via findOrCreateRoom
/// - Unread summary fetching
class OrdersScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String userRole;
  final VoidCallback onLogout;

  const OrdersScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.userRole,
    required this.onLogout,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late List<Order> _orders;
  Map<String, int> _unreadCounts = {};
  final Map<String, String> _roomToOrderMap = {};
  bool _isLoading = true;
  StreamSubscription<Message>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _orders = MockOrders.getOrdersForUser(widget.currentUserId, widget.userRole);
    _loadUnreadCountsAndObserve();
    _listenForMessages();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _listenForMessages() {
    final client = RiviumChatScope.read(context);
    _messageSubscription = client.onMessage.listen((message) {
      debugPrint('[RiviumChat] onMessage: sender=${message.senderUserId}, room=${message.roomId}, mapped=${_roomToOrderMap[message.roomId]}');
      if (message.senderUserId != widget.currentUserId) {
        final orderId = _roomToOrderMap[message.roomId];
        if (orderId != null) {
          setState(() {
            _unreadCounts[orderId] = (_unreadCounts[orderId] ?? 0) + 1;
          });
          debugPrint('[RiviumChat] Unread incremented: $orderId = ${_unreadCounts[orderId]}');
        }
      }
    });
  }

  Future<void> _loadUnreadCountsAndObserve() async {
    try {
      final client = RiviumChatScope.read(context);
      final summary = await client.getUnreadSummary();

      setState(() {
        _unreadCounts = {
          for (final room in summary.rooms)
            if (room.externalId != null) room.externalId!: room.unreadCount,
        };
        _isLoading = false;
      });

      // Subscribe to chat channels for real-time unread updates (without joining presence)
      for (final order in _orders) {
        try {
          final room = await client.getRoomByExternalId('order-${order.id}');
          _roomToOrderMap[room.id] = 'order-${order.id}';
          await client.observeRoom(room.id);
          debugPrint('[RiviumChat] Observing room ${room.id} for order-${order.id}');
        } catch (e) {
          debugPrint('[RiviumChat] Failed to observe order-${order.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to load unread counts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final client = RiviumChatScope.read(context);
      final summary = await client.getUnreadSummary();

      setState(() {
        _unreadCounts = {
          for (final room in summary.rooms)
            if (room.externalId != null) room.externalId!: room.unreadCount,
        };
      });

      // Re-observe rooms
      for (final roomId in _roomToOrderMap.keys) {
        await client.observeRoom(roomId);
      }
    } catch (e) {
      debugPrint('Failed to load unread counts: $e');
    }
  }

  Future<void> _openChat(Order order) async {
    final client = RiviumChatScope.read(context);

    // Determine the other party
    final isBuyer = widget.userRole == 'buyer';
    final otherUserName = isBuyer ? order.sellerName : order.buyerName;

    try {
      // Find or create the chat room for this order
      // This is idempotent - if the room exists, it returns the existing one
      final room = await client.findOrCreateRoom(
        externalId: 'order-${order.id}',
        type: RoomType.direct,
        name: 'Order ${order.orderNumber}',
        participants: [
          {
            'externalUserId': order.buyerId,
            'displayName': order.buyerName,
            'locale': 'en',
          },
          {
            'externalUserId': order.sellerId,
            'displayName': order.sellerName,
            'locale': 'en',
          },
        ],
        metadata: {
          'orderId': order.id,
          'orderNumber': order.orderNumber,
          'productName': order.productName,
          'productImage': order.productImage,
          'price': order.price,
          'quantity': order.quantity,
          'status': order.status.name,
          // Push notification variables
          'pushVariables': {
            'orderNumber': order.orderNumber,
            'productName': order.productName,
            'storeName': order.sellerName,
          },
          // Deep link for push notification tap
          'pushData': {
            'deepLink': 'myapp://orders/${order.id}/chat',
            'orderId': order.id,
          },
        },
      );

      if (!mounted) return;

      // Navigate to chat screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderChatScreen(
            roomId: room.id,
            order: order,
            currentUserId: widget.currentUserId,
            otherUserName: otherUserName,
          ),
        ),
      );

      // Refresh unread counts when returning
      _loadUnreadCounts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBuyer = widget.userRole == 'buyer';

    return Scaffold(
      appBar: AppBar(
        title: Text(isBuyer ? 'My Orders' : 'Customer Orders'),
        actions: [
          // Global unread badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_outlined),
                onPressed: () {
                  // Could navigate to all chats
                },
              ),
              const Positioned(
                right: 8,
                top: 8,
                child: UnreadBadge(
                  // null roomId = total unread across all rooms
                  roomId: null,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.currentUserName[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                widget.onLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.currentUserName,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      widget.userRole.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyState(theme, isBuyer)
              : RefreshIndicator(
                  onRefresh: _loadUnreadCounts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final unread = _unreadCounts['order-${order.id}'] ?? 0;
                      return _OrderCard(
                        order: order,
                        unreadCount: unread,
                        isBuyer: isBuyer,
                        onTap: () => _openChat(order),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isBuyer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBuyer ? Icons.shopping_bag_outlined : Icons.store_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isBuyer ? 'No orders yet' : 'No customer orders',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isBuyer
                  ? 'Your orders will appear here'
                  : 'Customer orders will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final int unreadCount;
  final bool isBuyer;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.unreadCount,
    required this.isBuyer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // Order header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  Text(
                    order.orderNumber,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(status: order.status),
                ],
              ),
            ),

            // Order content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      order.productImage,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Order details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isBuyer
                              ? 'Seller: ${order.sellerName}'
                              : 'Buyer: ${order.buyerName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '\$${order.total.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (order.quantity > 1) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${order.quantity} items)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(order.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chat button with unread badge
                  Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onError,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chat',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
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
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _getColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  (Color, Color) _getColors(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case OrderStatus.pending:
        return (Colors.orange.shade700, Colors.orange.shade50);
      case OrderStatus.confirmed:
        return (Colors.blue.shade700, Colors.blue.shade50);
      case OrderStatus.shipped:
        return (Colors.purple.shade700, Colors.purple.shade50);
      case OrderStatus.delivered:
        return (Colors.green.shade700, Colors.green.shade50);
      case OrderStatus.cancelled:
        return (theme.colorScheme.error, theme.colorScheme.errorContainer);
    }
  }
}
