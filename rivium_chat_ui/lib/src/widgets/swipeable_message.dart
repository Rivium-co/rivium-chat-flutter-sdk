import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A swipeable message wrapper that enables swipe-to-reply gesture.
/// Similar to WhatsApp and Telegram swipe-to-reply functionality.
class SwipeableMessage extends StatefulWidget {
  /// The message widget to wrap.
  final Widget child;

  /// Whether this message is from the current user.
  final bool isMe;

  /// Called when the user completes a swipe-to-reply gesture.
  final VoidCallback? onReply;

  /// The threshold (0.0 to 1.0) at which the reply action is triggered.
  /// Defaults to 0.2 (20% of screen width).
  final double replyThreshold;

  /// Whether swipe-to-reply is enabled.
  final bool enabled;

  /// Custom reply icon.
  final IconData replyIcon;

  /// Reply icon color.
  final Color? replyIconColor;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.isMe,
    this.onReply,
    this.replyThreshold = 0.2,
    this.enabled = true,
    this.replyIcon = Icons.reply,
    this.replyIconColor,
  });

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;
  bool _hasTriggeredHaptic = false;

  static const double _maxDragRatio = 0.3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _hasTriggeredHaptic = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || widget.onReply == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final delta = details.primaryDelta ?? 0;

    // For own messages (right side), swipe left (negative delta)
    // For other messages (left side), swipe right (positive delta)
    if (widget.isMe) {
      // Swipe left to reply
      _dragExtent = (_dragExtent + delta).clamp(-screenWidth * _maxDragRatio, 0);
    } else {
      // Swipe right to reply
      _dragExtent = (_dragExtent + delta).clamp(0, screenWidth * _maxDragRatio);
    }

    // Trigger haptic feedback when crossing threshold
    final threshold = screenWidth * widget.replyThreshold;
    if (_dragExtent.abs() >= threshold && !_hasTriggeredHaptic) {
      HapticFeedback.mediumImpact();
      _hasTriggeredHaptic = true;
    } else if (_dragExtent.abs() < threshold && _hasTriggeredHaptic) {
      _hasTriggeredHaptic = false;
    }

    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled || widget.onReply == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * widget.replyThreshold;

    if (_dragExtent.abs() >= threshold) {
      // Trigger reply
      HapticFeedback.lightImpact();
      widget.onReply?.call();
    }

    // Animate back to original position
    _animateBack();
  }

  void _animateBack() {
    final startValue = _dragExtent;
    _controller.reset();

    _animation = Tween<double>(begin: startValue, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _animation.addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onReply == null) {
      return widget.child;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * widget.replyThreshold;
    final progress = (_dragExtent.abs() / threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: widget.isMe ? Alignment.centerLeft : Alignment.centerRight,
        children: [
          // Reply icon indicator
          Positioned(
            left: widget.isMe ? 16 : null,
            right: widget.isMe ? null : 16,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hasTriggeredHaptic
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.replyIcon,
                    size: 20,
                    color: _hasTriggeredHaptic
                        ? Theme.of(context).colorScheme.onPrimary
                        : (widget.replyIconColor ??
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),

          // Message content
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
