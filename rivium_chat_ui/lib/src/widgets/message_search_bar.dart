import 'package:flutter/material.dart';

/// A search bar widget for searching messages in a chat.
/// Similar to the search functionality in Telegram and WhatsApp.
class MessageSearchBar extends StatefulWidget {
  /// Called when the search query changes.
  final void Function(String query)? onQueryChanged;

  /// Called when search is submitted.
  final void Function(String query)? onSubmitted;

  /// Called when the search bar is closed.
  final VoidCallback? onClose;

  /// Called to navigate to the previous result.
  final VoidCallback? onPrevious;

  /// Called to navigate to the next result.
  final VoidCallback? onNext;

  /// Current result index (1-based).
  final int currentResult;

  /// Total number of results.
  final int totalResults;

  /// Whether search is currently in progress.
  final bool isSearching;

  /// Placeholder text for the search field.
  final String placeholder;

  /// Whether to auto-focus the search field.
  final bool autofocus;

  /// Debounce duration for search queries.
  final Duration debounceDuration;

  const MessageSearchBar({
    super.key,
    this.onQueryChanged,
    this.onSubmitted,
    this.onClose,
    this.onPrevious,
    this.onNext,
    this.currentResult = 0,
    this.totalResults = 0,
    this.isSearching = false,
    this.placeholder = 'Search messages...',
    this.autofocus = true,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  State<MessageSearchBar> createState() => _MessageSearchBarState();
}

class _MessageSearchBarState extends State<MessageSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (query != _lastQuery) {
      _lastQuery = query;
      widget.onQueryChanged?.call(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back/Close button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onClose,
            tooltip: 'Close search',
          ),

          // Search field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),

          // Loading indicator or results count
          if (widget.isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (widget.totalResults > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${widget.currentResult}/${widget.totalResults}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else if (_controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'No results',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),

          // Clear button
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
                _focusNode.requestFocus();
              },
              tooltip: 'Clear',
            ),

          // Navigation buttons
          if (widget.totalResults > 1) ...[
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: widget.currentResult > 1 ? widget.onPrevious : null,
              tooltip: 'Previous result',
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: widget.currentResult < widget.totalResults
                  ? widget.onNext
                  : null,
              tooltip: 'Next result',
            ),
          ],
        ],
      ),
    );
  }
}

/// An overlay search bar that slides down from the top.
class MessageSearchOverlay extends StatefulWidget {
  /// Called when the search query changes.
  final void Function(String query)? onQueryChanged;

  /// Called when the overlay is dismissed.
  final VoidCallback? onDismiss;

  /// Current result index.
  final int currentResult;

  /// Total number of results.
  final int totalResults;

  /// Whether search is in progress.
  final bool isSearching;

  /// Called to navigate to previous result.
  final VoidCallback? onPrevious;

  /// Called to navigate to next result.
  final VoidCallback? onNext;

  const MessageSearchOverlay({
    super.key,
    this.onQueryChanged,
    this.onDismiss,
    this.currentResult = 0,
    this.totalResults = 0,
    this.isSearching = false,
    this.onPrevious,
    this.onNext,
  });

  @override
  State<MessageSearchOverlay> createState() => _MessageSearchOverlayState();
}

class _MessageSearchOverlayState extends State<MessageSearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 4,
        child: MessageSearchBar(
          onQueryChanged: widget.onQueryChanged,
          onClose: _dismiss,
          currentResult: widget.currentResult,
          totalResults: widget.totalResults,
          isSearching: widget.isSearching,
          onPrevious: widget.onPrevious,
          onNext: widget.onNext,
        ),
      ),
    );
  }
}

/// Highlighted text widget for search results.
class HighlightedSearchText extends StatelessWidget {
  /// The full text to display.
  final String text;

  /// The search query to highlight.
  final String query;

  /// Style for non-highlighted text.
  final TextStyle? style;

  /// Style for highlighted text.
  final TextStyle? highlightStyle;

  /// Background color for highlighted text.
  final Color? highlightBackgroundColor;

  /// Maximum lines to display.
  final int? maxLines;

  /// Text overflow behavior.
  final TextOverflow? overflow;

  const HighlightedSearchText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.highlightBackgroundColor,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    final defaultHighlightStyle = highlightStyle ??
        defaultStyle.copyWith(
          fontWeight: FontWeight.bold,
          backgroundColor: highlightBackgroundColor ??
              Theme.of(context).colorScheme.primaryContainer,
        );

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // Add non-highlighted text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: defaultStyle,
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: defaultHighlightStyle,
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
