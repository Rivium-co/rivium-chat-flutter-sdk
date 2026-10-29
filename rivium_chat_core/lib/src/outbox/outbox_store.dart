import 'pending_message.dart';

/// Where the outbox keeps messages written while offline.
///
/// The default ([MemoryOutboxStore]) survives a lost network, not an app
/// restart. Implement this with the storage your app already uses (for
/// example shared_preferences: `jsonEncode` the items' `toJson()` under one
/// key per project and user) to keep them across restarts.
abstract class OutboxStore {
  /// Returns the saved messages in the order they were written.
  Future<List<PendingMessage>> load();

  /// Replaces the saved messages with [items].
  Future<void> save(List<PendingMessage> items);
}

/// Keeps the outbox in memory only (the default).
class MemoryOutboxStore implements OutboxStore {
  List<PendingMessage> _items = const [];

  @override
  Future<List<PendingMessage>> load() async => List.of(_items);

  @override
  Future<void> save(List<PendingMessage> items) async {
    _items = List.unmodifiable(items);
  }
}
