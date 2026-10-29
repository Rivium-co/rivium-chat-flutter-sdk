import 'message.dart';

/// One page of message search results.
class SearchResult {
  /// The matching messages on this page.
  final List<Message> messages;

  /// Number of messages that match the query, across all pages.
  final int total;

  /// Whether more matches follow this page (`offset + messages.length < total`).
  final bool hasMore;

  const SearchResult({
    required this.messages,
    required this.total,
    required this.hasMore,
  });
}
