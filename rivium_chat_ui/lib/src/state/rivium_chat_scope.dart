import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:rivium_chat/rivium_chat.dart';

/// Provides the RiviumChatClient to the widget tree.
///
/// This is the root widget for RiviumChat UI. Place it near the top
/// of your widget tree to provide chat functionality to all descendants.
///
/// ```dart
/// RiviumChatScope(
///   config: config,
///   child: MyApp(),
/// )
/// ```
class RiviumChatScope extends StatefulWidget {
  /// The RiviumChat configuration.
  final RiviumChatConfig config;

  /// Whether to automatically connect on mount.
  final bool autoConnect;

  /// Called when the client connects.
  final VoidCallback? onConnected;

  /// Called when a connection error occurs.
  final void Function(Object error)? onError;

  /// The child widget.
  final Widget child;

  const RiviumChatScope({
    super.key,
    required this.config,
    this.autoConnect = true,
    this.onConnected,
    this.onError,
    required this.child,
  });

  /// Gets the RiviumChatClient from the nearest ancestor.
  static RiviumChatClient of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RiviumChatInherited>();
    if (scope == null) {
      throw FlutterError(
        'RiviumChatScope.of() called with a context that does not contain a RiviumChatScope.\n'
        'Ensure that RiviumChatScope is an ancestor of the widget calling RiviumChatScope.of().',
      );
    }
    return scope.client;
  }

  /// Gets the RiviumChatClient without establishing a dependency.
  static RiviumChatClient read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_RiviumChatInherited>();
    if (scope == null) {
      throw FlutterError(
        'RiviumChatScope.read() called with a context that does not contain a RiviumChatScope.\n'
        'Ensure that RiviumChatScope is an ancestor of the widget calling RiviumChatScope.read().',
      );
    }
    return scope.client;
  }

  /// Tries to get the RiviumChatClient, returns null if not found.
  static RiviumChatClient? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RiviumChatInherited>();
    return scope?.client;
  }

  @override
  State<RiviumChatScope> createState() => _RiviumChatScopeState();
}

class _RiviumChatScopeState extends State<RiviumChatScope> {
  late RiviumChatClient _client;
  StreamSubscription<ConnectionErrorEvent>? _errorSub;

  @override
  void initState() {
    super.initState();
    _client = RiviumChatClient(widget.config);

    _errorSub = _client.onConnectionError.listen((event) {
      widget.onError?.call(event.error);
    });

    if (widget.autoConnect) {
      _connect();
    }
  }

  Future<void> _connect() async {
    try {
      await _client.connect();
      widget.onConnected?.call();
    } catch (e) {
      widget.onError?.call(e);
    }
  }

  @override
  void didUpdateWidget(RiviumChatScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate client if config changes
    if (oldWidget.config.apiKey != widget.config.apiKey ||
        oldWidget.config.userId != widget.config.userId) {
      _errorSub?.cancel();
      _client.dispose();

      _client = RiviumChatClient(widget.config);
      _errorSub = _client.onConnectionError.listen((event) {
        widget.onError?.call(event.error);
      });

      if (widget.autoConnect) {
        _connect();
      }
    }
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RiviumChatInherited(
      client: _client,
      child: widget.child,
    );
  }
}

class _RiviumChatInherited extends InheritedWidget {
  final RiviumChatClient client;

  const _RiviumChatInherited({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_RiviumChatInherited oldWidget) {
    return client != oldWidget.client;
  }
}

/// Provides an existing RiviumChatClient to the widget tree.
///
/// Use this when you already have a RiviumChatClient instance (e.g., from Riverpod
/// or another state management solution) and want to use it with RiviumChat UI widgets.
///
/// Unlike [RiviumChatScope], this widget does NOT create or manage the client lifecycle.
/// You are responsible for creating, connecting, and disposing the client.
///
/// ```dart
/// final client = ref.read(riviumChatClientProvider);
/// RiviumChatProvider(
///   client: client,
///   child: ChatScreen(roomId: 'room-123', currentUserId: 'user-456'),
/// )
/// ```
class RiviumChatProvider extends StatelessWidget {
  /// The existing RiviumChatClient to provide.
  final RiviumChatClient client;

  /// The child widget.
  final Widget child;

  const RiviumChatProvider({
    super.key,
    required this.client,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _RiviumChatInherited(
      client: client,
      child: child,
    );
  }
}
