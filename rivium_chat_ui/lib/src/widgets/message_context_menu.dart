import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';

/// Actions available in the message context menu.
enum MessageAction {
  reply,
  edit,
  delete,
  pin,
  unpin,
}

/// Shows a context menu for a message.
Future<void> showMessageContextMenu({
  required BuildContext context,
  required Message message,
  required Offset position,
  required bool canDelete,
  required bool canEdit,
  required bool canReply,
  required bool isPinned,
  required void Function(MessageAction) onAction,
  void Function(String emoji)? onReact,
}) async {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _ContextMenuOverlay(
      position: position,
      message: message,
      canDelete: canDelete,
      canEdit: canEdit,
      canReply: canReply,
      isPinned: isPinned,
      onAction: (action) {
        entry.remove();
        onAction(action);
      },
      onReact: onReact != null
          ? (emoji) {
              entry.remove();
              onReact(emoji);
            }
          : null,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _ContextMenuOverlay extends StatelessWidget {
  final Offset position;
  final Message message;
  final bool canDelete;
  final bool canEdit;
  final bool canReply;
  final bool isPinned;
  final void Function(MessageAction) onAction;
  final void Function(String emoji)? onReact;
  final VoidCallback onDismiss;

  const _ContextMenuOverlay({
    required this.position,
    required this.message,
    required this.canDelete,
    required this.canEdit,
    required this.canReply,
    required this.isPinned,
    required this.onAction,
    this.onReact,
    required this.onDismiss,
  });

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🎉'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.black26,
        child: Stack(
          children: [
            Positioned(
              left: position.dx.clamp(16, MediaQuery.of(context).size.width - 200),
              top: position.dy.clamp(100, MediaQuery.of(context).size.height - 300),
              child: _buildMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick reactions
          if (onReact != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickReactions.map((emoji) {
                  return GestureDetector(
                    onTap: () => onReact!(emoji),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  );
                }).toList(),
              ),
            ),

          if (onReact != null)
            Divider(height: 1, color: Theme.of(context).dividerColor),

          // Menu items
          if (canReply)
            _MenuItem(
              icon: Icons.reply,
              label: 'Reply',
              onTap: () => onAction(MessageAction.reply),
            ),

          if (canEdit)
            _MenuItem(
              icon: Icons.edit,
              label: 'Edit',
              onTap: () => onAction(MessageAction.edit),
            ),

          _MenuItem(
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: isPinned ? 'Unpin' : 'Pin',
            onTap: () => onAction(isPinned ? MessageAction.unpin : MessageAction.pin),
          ),

          if (canDelete)
            _MenuItem(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: () => onAction(MessageAction.delete),
              isDestructive: true,
            ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
