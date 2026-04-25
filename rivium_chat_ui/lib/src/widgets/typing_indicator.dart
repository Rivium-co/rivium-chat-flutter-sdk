import 'package:flutter/material.dart';
import '../state/chat_channel_scope.dart';

/// Displays a typing indicator for a chat room.
class TypingIndicator extends StatelessWidget {
  final String roomId;
  final Widget Function(BuildContext, List<String>)? builder;

  const TypingIndicator({
    super.key,
    required this.roomId,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final state = ChatChannelScope.of(context);
    final typingUsers = state.typingUsers.toList();

    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    if (builder != null) {
      return builder!(context, typingUsers);
    }

    final names = state.participantDisplayNames;
    final displayText = typingUsers.length == 1
        ? '${names[typingUsers.first] ?? typingUsers.first} is typing...'
        : '${typingUsers.length} people are typing...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const TypingDots(),
          const SizedBox(width: 8),
          Text(
            displayText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing dots widget.
///
/// A standalone widget that displays animated bouncing dots,
/// commonly used to indicate someone is typing.
///
/// This can be used independently of [TypingIndicator] when you
/// manage typing state externally (e.g., via Riverpod or other state management).
class TypingDots extends StatefulWidget {
  /// The color of the dots. Defaults to theme's onSurfaceVariant.
  final Color? color;

  /// The size of each dot.
  final double dotSize;

  /// The spacing between dots.
  final double spacing;

  /// Animation duration for the full cycle.
  final Duration duration;

  const TypingDots({
    super.key,
    this.color,
    this.dotSize = 6,
    this.spacing = 2,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.spacing),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
