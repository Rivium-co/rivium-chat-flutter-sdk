import 'package:flutter/material.dart';
import '../state/chat_channel_scope.dart';

/// Displays an online/offline presence indicator.
class PresenceIndicator extends StatelessWidget {
  final String roomId;
  final String userId;
  final double size;
  final Color? onlineColor;
  final Color? offlineColor;

  const PresenceIndicator({
    super.key,
    required this.roomId,
    required this.userId,
    this.size = 10,
    this.onlineColor,
    this.offlineColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = ChatChannelScope.of(context);
    final isOnline = state.isUserOnline(userId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline
            ? (onlineColor ?? Colors.green)
            : (offlineColor ?? Colors.grey),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    );
  }
}
