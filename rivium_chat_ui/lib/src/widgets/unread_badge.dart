import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';
import '../state/rivium_chat_scope.dart';

/// Displays an unread message count badge.
class UnreadBadge extends StatefulWidget {
  /// If null, shows total unread count. Otherwise shows unread for specific room.
  final String? roomId;
  final Color? backgroundColor;
  final Color? textColor;
  final double size;
  final TextStyle? textStyle;

  const UnreadBadge({
    super.key,
    this.roomId,
    this.backgroundColor,
    this.textColor,
    this.size = 20,
    this.textStyle,
  });

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge> {
  UnreadSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final client = RiviumChatScope.read(context);
      final summary = await client.getUnreadSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _summary == null) {
      return const SizedBox.shrink();
    }

    int count;
    if (widget.roomId != null) {
      final roomUnread = _summary!.rooms.where((r) => r.roomId == widget.roomId);
      count = roomUnread.isNotEmpty ? roomUnread.first.unreadCount : 0;
    } else {
      count = _summary!.totalUnread;
    }

    if (count == 0) {
      return const SizedBox.shrink();
    }

    final displayCount = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: BoxConstraints(
        minWidth: widget.size,
        minHeight: widget.size,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(widget.size / 2),
      ),
      child: Center(
        child: Text(
          displayCount,
          style: widget.textStyle ??
              TextStyle(
                color: widget.textColor ??
                    Theme.of(context).colorScheme.onError,
                fontSize: widget.size * 0.6,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
