import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../events/events.dart';
import '../models/message.dart';
import 'outbox_store.dart';
import 'pending_message.dart';

/// Keeps messages written without network and sends them when the
/// connection is back: one at a time, in the order written, never twice
/// (every message carries its clientMessageId, so a resend whose first answer
/// was lost is stored once by the server).
class Outbox {
  static const initialBackoff = Duration(seconds: 2);
  static const maxBackoff = Duration(seconds: 60);
  static const maxAge = Duration(hours: 24);

  final OutboxStore _store;
  final String _userId;
  final Future<Message> Function(PendingMessage) _sender;
  final void Function(MessageSentEvent) _onSent;
  final void Function(MessageFailedEvent) _onFailed;
  final DateTime Function() _now;

  final List<PendingMessage> _items = [];
  late final Future<void> _loaded;

  /// Flushes run one after the other: racing triggers wait, then find the
  /// sent items gone.
  Future<void> _flushChain = Future.value();
  Future<void> _saveChain = Future.value();
  Timer? _retryTimer;
  Duration _backoff = Duration.zero;
  bool _disposed = false;

  Outbox({
    required OutboxStore store,
    required String userId,
    required Future<Message> Function(PendingMessage) sender,
    required void Function(MessageSentEvent) onSent,
    required void Function(MessageFailedEvent) onFailed,
    DateTime Function()? now,
  })  : _store = store,
        _userId = userId,
        _sender = sender,
        _onSent = onSent,
        _onFailed = onFailed,
        _now = now ?? DateTime.now {
    _loaded = _load();
  }

  Future<void> _load() async {
    try {
      final stored = await _store.load();
      // Items another user wrote on this device are never sent.
      _items.insertAll(0, stored.where((p) => p.senderUserId == _userId));
    } catch (_) {
      // Best effort: start with an empty queue.
    }
  }

  /// Completes once the store's items are loaded.
  Future<void> get ready => _loaded;

  /// The current back-off ([Duration.zero] = none since the last success).
  Duration get currentBackoff => _backoff;

  void _persist() {
    final snapshot = List<PendingMessage>.of(_items);
    _saveChain = _saveChain.then((_) => _store.save(snapshot)).catchError((_) {});
  }

  bool _remove(String localId) {
    final before = _items.length;
    _items.removeWhere((p) => p.localId == localId);
    final removed = _items.length != before;
    if (removed) _persist();
    return removed;
  }

  /// Sends [item] now, or queues it when the failure is transient (or when
  /// older messages of the same room still wait, so the order is kept).
  /// Permanent failures are thrown.
  Future<Message> send(PendingMessage item) async {
    await _loaded;
    if (_items.any((p) => p.roomId == item.roomId)) {
      _items.add(item);
      _persist();
      unawaited(flush());
      return item.toMessage();
    }
    try {
      return await _sender(item);
    } catch (e) {
      if (!isTransient(e)) rethrow;
      _items.add(item);
      _persist();
      _scheduleRetry();
      return item.toMessage();
    }
  }

  /// The realtime connection is up: send what waits.
  void onConnected() {
    if (_disposed) return;
    unawaited(flush());
  }

  /// Sends what waits; completes when done (or stopped by a transient failure).
  Future<void> flush() {
    if (_disposed) return Future.value();
    final run = _flushChain.then((_) => _flushOnce());
    _flushChain = run.catchError((_) {});
    return _flushChain;
  }

  Future<void> _flushOnce() async {
    await _loaded;
    while (!_disposed && _items.isNotEmpty) {
      final next = _items.first;

      if (_now().difference(next.createdAt) > maxAge) {
        if (_remove(next.localId)) {
          _onFailed(MessageFailedEvent(
            localId: next.localId,
            clientMessageId: next.clientMessageId,
            roomId: next.roomId,
            error: 'The message waited more than 24 hours without network',
            reason: MessageFailedEvent.reasonExpired,
          ));
        }
        continue;
      }

      final Message message;
      try {
        message = await _sender(next);
      } catch (e) {
        if (isTransient(e)) {
          _scheduleRetry();
          return;
        }
        if (_remove(next.localId)) {
          _onFailed(MessageFailedEvent(
            localId: next.localId,
            clientMessageId: next.clientMessageId,
            roomId: next.roomId,
            error: e.toString(),
            reason: MessageFailedEvent.reasonRejected,
          ));
        }
        continue;
      }

      _backoff = Duration.zero;
      // Cancelled while it was being sent: stored anyway, but no messageSent.
      if (_remove(next.localId)) {
        _onSent(MessageSentEvent(
          localId: next.localId,
          clientMessageId: next.clientMessageId,
          message: message,
        ));
      }
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _backoff = _backoff == Duration.zero
        ? initialBackoff
        : (_backoff * 2 > maxBackoff ? maxBackoff : _backoff * 2);
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff, () {
      _retryTimer = null;
      unawaited(flush());
    });
  }

  /// What waits, oldest first; only [roomId]'s when given.
  Future<List<PendingMessage>> pending({String? roomId}) async {
    await _loaded;
    return _items.where((p) => roomId == null || p.roomId == roomId).toList();
  }

  Future<bool> cancel(String localId) async {
    await _loaded;
    return _remove(localId);
  }

  Future<void> clear() async {
    await _loaded;
    _items.clear();
    _persist();
    await _saveChain;
  }

  /// Forgets everything in memory; a persistent store keeps its copy.
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _items.clear();
  }

  /// Transient: no HTTP answer (no network, timeout, a failing tokenProvider),
  /// a 5xx, 408 or 429. Every other 4xx (400, 401, 403, 404, 413 …) is
  /// permanent.
  static bool isTransient(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) return status >= 500 || status == 408 || status == 429;
      return error.type != DioExceptionType.cancel;
    }
    return error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is HandshakeException;
  }
}
