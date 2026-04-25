import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A user who has read a message.
class ReadReceiptUser {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final DateTime readAt;

  const ReadReceiptUser({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.readAt,
  });
}

/// Message delivery and read status.
enum MessageStatus {
  /// Message is being sent.
  sending,

  /// Message has been sent to the server.
  sent,

  /// Message has been delivered to the recipient's device.
  delivered,

  /// Message has been read by the recipient.
  read,

  /// Message failed to send.
  failed,
}

/// A widget that displays read receipts for a message.
/// Shows check marks (like WhatsApp) or user avatars (like Messenger).
class ReadReceipts extends StatelessWidget {
  /// The current delivery/read status of the message.
  final MessageStatus status;

  /// List of users who have read the message.
  final List<ReadReceiptUser>? readBy;

  /// Whether to show avatars for group chats.
  final bool showAvatars;

  /// Maximum number of avatars to show.
  final int maxAvatars;

  /// Size of the status icon.
  final double iconSize;

  /// Size of user avatars.
  final double avatarSize;

  /// Color for the read status.
  final Color? readColor;

  /// Color for the sent/delivered status.
  final Color? sentColor;

  /// Color for the failed status.
  final Color? failedColor;

  /// Called when the receipts are tapped (to show details).
  final VoidCallback? onTap;

  const ReadReceipts({
    super.key,
    required this.status,
    this.readBy,
    this.showAvatars = false,
    this.maxAvatars = 3,
    this.iconSize = 16,
    this.avatarSize = 14,
    this.readColor,
    this.sentColor,
    this.failedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (showAvatars && readBy != null && readBy!.isNotEmpty) {
      return _buildAvatarReceipts(context);
    }

    return _buildCheckmarkReceipts(context);
  }

  Widget _buildCheckmarkReceipts(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = sentColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = sentColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = sentColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = readColor ?? Theme.of(context).colorScheme.primary;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = failedColor ?? Theme.of(context).colorScheme.error;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: iconSize, color: color),
    );
  }

  Widget _buildAvatarReceipts(BuildContext context) {
    final users = readBy!.take(maxAvatars).toList();
    final remaining = readBy!.length - maxAvatars;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Overlapping avatars
          SizedBox(
            width: avatarSize + (users.length - 1) * (avatarSize * 0.6),
            height: avatarSize,
            child: Stack(
              children: users.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;

                return Positioned(
                  left: index * (avatarSize * 0.6),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: avatarSize / 2 - 1,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: user.avatarUrl != null
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              _getInitial(user.displayName),
                              style: TextStyle(
                                fontSize: avatarSize * 0.4,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Remaining count
          if (remaining > 0) ...[
            const SizedBox(width: 2),
            Text(
              '+$remaining',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

/// A bottom sheet that shows detailed read receipt information.
class ReadReceiptDetails extends StatelessWidget {
  /// List of users who have read the message.
  final List<ReadReceiptUser> readBy;

  /// Message sent time.
  final DateTime? sentAt;

  /// Message delivered time.
  final DateTime? deliveredAt;

  const ReadReceiptDetails({
    super.key,
    required this.readBy,
    this.sentAt,
    this.deliveredAt,
  });

  /// Shows the read receipt details as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<ReadReceiptUser> readBy,
    DateTime? sentAt,
    DateTime? deliveredAt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ReadReceiptDetails(
          readBy: readBy,
          sentAt: sentAt,
          deliveredAt: deliveredAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Message info',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          const Divider(),

          // Status section
          if (sentAt != null || deliveredAt != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sentAt != null)
                    _buildStatusRow(
                      context,
                      icon: Icons.done,
                      label: 'Sent',
                      time: sentAt!,
                    ),
                  if (deliveredAt != null) ...[
                    const SizedBox(height: 8),
                    _buildStatusRow(
                      context,
                      icon: Icons.done_all,
                      label: 'Delivered',
                      time: deliveredAt!,
                    ),
                  ],
                ],
              ),
            ),

          // Read by section
          if (readBy.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.done_all,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Read by ${readBy.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: readBy.length,
                itemBuilder: (context, index) {
                  final user = readBy[index];
                  return _buildUserRow(context, user);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DateTime time,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          _formatTime(time),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildUserRow(BuildContext context, ReadReceiptUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: user.avatarUrl != null
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.displayName?[0].toUpperCase() ?? '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.displayName ?? 'Unknown',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            _formatTime(user.readAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timeDate = DateTime(time.year, time.month, time.day);

    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (timeDate == today) {
      return timeStr;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (timeDate == yesterday) {
      return 'Yesterday, $timeStr';
    }

    return '${time.day}/${time.month}/${time.year}, $timeStr';
  }
}
