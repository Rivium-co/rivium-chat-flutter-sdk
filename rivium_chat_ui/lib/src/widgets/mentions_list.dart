import 'package:flutter/material.dart';

/// A user to display in the mentions list.
class MentionUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isOnline;

  const MentionUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isOnline = false,
  });
}

/// A widget that displays an autocomplete list for @mentions.
/// Shows when the user types '@' in the input field.
class MentionsList extends StatelessWidget {
  /// List of users that can be mentioned.
  final List<MentionUser> users;

  /// The current search query (text after '@').
  final String query;

  /// Called when a user is selected from the list.
  final void Function(MentionUser user) onUserSelected;

  /// Maximum number of suggestions to show.
  final int maxSuggestions;

  /// Custom item builder for mention suggestions.
  final Widget Function(BuildContext, MentionUser)? itemBuilder;

  /// Background color of the list.
  final Color? backgroundColor;

  /// Border radius of the list container.
  final BorderRadius? borderRadius;

  /// Elevation of the list container.
  final double elevation;

  const MentionsList({
    super.key,
    required this.users,
    required this.query,
    required this.onUserSelected,
    this.maxSuggestions = 5,
    this.itemBuilder,
    this.backgroundColor,
    this.borderRadius,
    this.elevation = 4,
  });

  List<MentionUser> get _filteredUsers {
    if (query.isEmpty) {
      return users.take(maxSuggestions).toList();
    }

    final lowerQuery = query.toLowerCase();
    return users
        .where((user) => user.displayName.toLowerCase().contains(lowerQuery))
        .take(maxSuggestions)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: elevation,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final user = filtered[index];
            if (itemBuilder != null) {
              return GestureDetector(
                onTap: () => onUserSelected(user),
                child: itemBuilder!(context, user),
              );
            }
            return _MentionUserTile(
              user: user,
              query: query,
              onTap: () => onUserSelected(user),
            );
          },
        ),
      ),
    );
  }
}

class _MentionUserTile extends StatelessWidget {
  final MentionUser user;
  final String query;
  final VoidCallback onTap;

  const _MentionUserTile({
    required this.user,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName[0].toUpperCase(),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Name with highlighted query
            Expanded(
              child: _HighlightedText(
                text: user.displayName,
                query: query,
                style: Theme.of(context).textTheme.bodyMedium!,
                highlightStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text, style: style);
    }

    final endIndex = startIndex + query.length;

    return RichText(
      text: TextSpan(
        children: [
          if (startIndex > 0)
            TextSpan(text: text.substring(0, startIndex), style: style),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: highlightStyle,
          ),
          if (endIndex < text.length)
            TextSpan(text: text.substring(endIndex), style: style),
        ],
      ),
    );
  }
}

/// Controller to manage mentions in a text input.
class MentionsController {
  final TextEditingController textController;
  final List<MentionUser> availableUsers;

  String? _currentMentionQuery;
  int? _mentionStartIndex;

  MentionsController({
    required this.textController,
    required this.availableUsers,
  }) {
    textController.addListener(_onTextChanged);
  }

  /// Current mention query (text after '@'), or null if not mentioning.
  String? get currentQuery => _currentMentionQuery;

  /// Whether the user is currently typing a mention.
  bool get isMentioning => _currentMentionQuery != null;

  void _onTextChanged() {
    final text = textController.text;
    final selection = textController.selection;

    if (!selection.isValid || selection.start != selection.end) {
      _currentMentionQuery = null;
      _mentionStartIndex = null;
      return;
    }

    final cursorPos = selection.start;
    if (cursorPos == 0) {
      _currentMentionQuery = null;
      _mentionStartIndex = null;
      return;
    }

    // Find the last '@' before cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) {
      _currentMentionQuery = null;
      _mentionStartIndex = null;
      return;
    }

    // Check if there's a space between @ and cursor
    final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
    if (textAfterAt.contains(' ') || textAfterAt.contains('\n')) {
      _currentMentionQuery = null;
      _mentionStartIndex = null;
      return;
    }

    // Check if @ is at start or preceded by space
    if (lastAtIndex > 0 &&
        text[lastAtIndex - 1] != ' ' &&
        text[lastAtIndex - 1] != '\n') {
      _currentMentionQuery = null;
      _mentionStartIndex = null;
      return;
    }

    _mentionStartIndex = lastAtIndex;
    _currentMentionQuery = textAfterAt;
  }

  /// Insert a mention into the text.
  void insertMention(MentionUser user) {
    if (_mentionStartIndex == null) return;

    final text = textController.text;
    final beforeMention = text.substring(0, _mentionStartIndex!);
    final afterMention = text.substring(textController.selection.start);

    final mentionText = '@${user.displayName} ';
    final newText = beforeMention + mentionText + afterMention;

    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: beforeMention.length + mentionText.length,
      ),
    );

    _currentMentionQuery = null;
    _mentionStartIndex = null;
  }

  void dispose() {
    textController.removeListener(_onTextChanged);
  }
}
