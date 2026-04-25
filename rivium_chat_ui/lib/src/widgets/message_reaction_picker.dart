import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A floating reaction picker bar that appears above messages.
/// Similar to Instagram, WhatsApp, and Telegram reaction pickers.
class MessageReactionPicker extends StatefulWidget {
  /// Called when a reaction is selected.
  final void Function(String emoji) onReactionSelected;

  /// Called when the picker is dismissed.
  final VoidCallback? onDismiss;

  /// List of quick reactions to display.
  final List<String> reactions;

  /// Whether to show the "more" button for full emoji picker.
  final bool showMoreButton;

  /// Called when "more" button is tapped.
  final VoidCallback? onMoreTap;

  /// Position anchor for the picker.
  final Alignment alignment;

  /// Background color of the picker.
  final Color? backgroundColor;

  /// Border radius of the picker.
  final BorderRadius? borderRadius;

  /// Elevation of the picker.
  final double elevation;

  const MessageReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.onDismiss,
    this.reactions = const ['👍', '❤️', '😂', '😮', '😢', '🔥', '🎉'],
    this.showMoreButton = true,
    this.onMoreTap,
    this.alignment = Alignment.center,
    this.backgroundColor,
    this.borderRadius,
    this.elevation = 8,
  });

  /// Shows the reaction picker as an overlay at the given position.
  static Future<String?> show(
    BuildContext context, {
    required Offset position,
    List<String> reactions = const ['👍', '❤️', '😂', '😮', '😢', '🔥', '🎉'],
    bool showMoreButton = true,
    VoidCallback? onMoreTap,
  }) async {
    String? selectedReaction;

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => _ReactionPickerDialog(
        position: position,
        reactions: reactions,
        showMoreButton: showMoreButton,
        onReactionSelected: (emoji) {
          selectedReaction = emoji;
          Navigator.pop(context);
        },
        onMoreTap: () {
          Navigator.pop(context);
          onMoreTap?.call();
        },
      ),
    );

    return selectedReaction;
  }

  @override
  State<MessageReactionPicker> createState() => _MessageReactionPickerState();
}

class _MessageReactionPickerState extends State<MessageReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: widget.alignment,
      child: Material(
        elevation: widget.elevation,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(28),
        color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.reactions.asMap().entries.map((entry) {
                return _ReactionButton(
                  emoji: entry.value,
                  isSelected: _selectedIndex == entry.key,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedIndex = entry.key);
                    widget.onReactionSelected(entry.value);
                  },
                  onHover: (hovering) {
                    if (hovering) {
                      setState(() => _selectedIndex = entry.key);
                    } else if (_selectedIndex == entry.key) {
                      setState(() => _selectedIndex = null);
                    }
                  },
                );
              }),
              if (widget.showMoreButton) ...[
                const SizedBox(width: 4),
                _MoreButton(onTap: widget.onMoreTap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(bool hovering) onHover;

  const _ReactionButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant _ReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _MoreButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ReactionPickerDialog extends StatelessWidget {
  final Offset position;
  final List<String> reactions;
  final bool showMoreButton;
  final void Function(String emoji) onReactionSelected;
  final VoidCallback? onMoreTap;

  const _ReactionPickerDialog({
    required this.position,
    required this.reactions,
    required this.showMoreButton,
    required this.onReactionSelected,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final pickerWidth = (reactions.length * 40.0) +
        (showMoreButton ? 52 : 16);

    // Calculate position to keep picker on screen
    double left = position.dx - pickerWidth / 2;
    double top = position.dy - 60;

    // Clamp to screen bounds
    left = left.clamp(8.0, screenSize.width - pickerWidth - 8);
    top = top.clamp(8.0, screenSize.height - 60);

    return Stack(
      children: [
        // Dismiss area
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
          ),
        ),

        // Picker
        Positioned(
          left: left,
          top: top,
          child: MessageReactionPicker(
            reactions: reactions,
            showMoreButton: showMoreButton,
            onReactionSelected: onReactionSelected,
            onMoreTap: onMoreTap,
          ),
        ),
      ],
    );
  }
}

/// A widget that displays reactions on a message.
class MessageReactions extends StatelessWidget {
  /// Map of emoji to list of user IDs who reacted.
  final Map<String, List<String>> reactions;

  /// Current user's ID.
  final String? currentUserId;

  /// Called when a reaction is tapped (to toggle).
  final void Function(String emoji)? onReactionTap;

  /// Called when reactions are long pressed (to show details).
  final void Function(String emoji)? onReactionLongPress;

  /// Whether this is on the current user's message.
  final bool isMe;

  const MessageReactions({
    super.key,
    required this.reactions,
    this.currentUserId,
    this.onReactionTap,
    this.onReactionLongPress,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final hasMyReaction = currentUserId != null &&
            users.contains(currentUserId);

        return GestureDetector(
          onTap: () => onReactionTap?.call(emoji),
          onLongPress: () => onReactionLongPress?.call(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasMyReaction
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: hasMyReaction
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                if (users.length > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${users.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: hasMyReaction
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
