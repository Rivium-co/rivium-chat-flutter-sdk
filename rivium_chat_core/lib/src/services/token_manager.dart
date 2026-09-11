import 'dart:async';
import 'dart:convert';

import '../config.dart';

/// Holds the current user token and refreshes it through
/// [RiviumChatConfig.tokenProvider].
///
/// - Reuses the cached token until shortly before it expires, then fetches a
///   new one before the request, so an expired token rarely reaches the server.
/// - Concurrent callers share one in-flight refresh: a burst of requests
///   triggers a single call to your server.
class TokenManager {
  TokenManager(this._provider, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ChatTokenProvider _provider;
  final DateTime Function() _clock;

  /// Refresh this long before `exp`, to absorb clock skew and request time.
  static const refreshMargin = Duration(seconds: 60);

  String? _token;
  DateTime? _expiresAt;
  Future<String>? _inFlight;

  /// A token that is valid for at least [refreshMargin].
  Future<String> get() {
    final token = _token;
    final expiresAt = _expiresAt;
    if (token != null &&
        (expiresAt == null || _clock().isBefore(expiresAt.subtract(refreshMargin)))) {
      return Future.value(token);
    }
    return refresh();
  }

  /// Fetches a new token, even if the cached one looks valid (used after the
  /// server answered `token_expired`). Joins a refresh already in flight.
  Future<String> refresh() {
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<String> _fetch() async {
    final token = await _provider();
    _token = token;
    _expiresAt = expiryOf(token);
    return token;
  }

  /// Forgets the cached token.
  void clear() {
    _token = null;
    _expiresAt = null;
  }

  /// The `exp` claim of a JWT, or null if it has none or cannot be read.
  static DateTime? expiryOf(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? payload['exp'] : null;
      return exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000) : null;
    } catch (_) {
      return null;
    }
  }
}
