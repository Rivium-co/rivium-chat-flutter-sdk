import 'dart:io';
import 'models/attachment.dart';
import 'outbox/outbox_store.dart';

/// Result of a file upload operation.
class FileUploadResult {
  final String url;
  final String? mimeType;
  final String? name;
  final int? size;

  const FileUploadResult({
    required this.url,
    this.mimeType,
    this.name,
    this.size,
  });

  /// Converts to an Attachment for use in messages.
  Attachment toAttachment() => Attachment(
        url: url,
        mimeType: mimeType,
        name: name,
        size: size,
      );
}

/// Callback type for uploading files.
///
/// Implement this to integrate with your storage service (S3, Firebase, Supabase, etc.).
typedef FileUploader = Future<FileUploadResult> Function(File file);

/// Returns a user token for the current user, issued by your server.
///
/// Your server calls `POST https://chat.rivium.co/api/v1/users/token` with the
/// `x-server-secret` header and returns the `token` to the app. Never put the
/// server secret in the app.
typedef ChatTokenProvider = Future<String> Function();

/// Configuration for the RiviumChat SDK.
class RiviumChatConfig {
  /// Base URL for the RiviumChat REST API.
  static const String baseUrl = 'https://chat.rivium.co';

  /// WebSocket URL for the realtime connection.
  static const String realtimeUrl =
      'wss://ws-chat.rivium.co/connection/websocket';

  /// WebSocket URL for the realtime connection.
  @Deprecated('Use realtimeUrl')
  static const String centrifugoUrl = realtimeUrl;

  /// Timeout for REST calls.
  ///
  /// Without this Dio inherits the platform default, which on iOS is long
  /// enough that a request issued while the app is backgrounding hangs
  /// instead of failing.
  final Duration httpTimeout;

  /// API key for authentication.
  final String apiKey;

  /// Current user's external ID.
  final String userId;

  /// Optional custom user info to include in the realtime connection token.
  final Map<String, dynamic>? userInfo;

  /// Optional file uploader callback for sending attachments.
  final FileUploader? fileUploader;

  /// Recommended. Proves who the user is: every request carries a token your
  /// server issued, so nobody holding the public [apiKey] can act as another
  /// user. The SDK calls it on connect, shortly before the token expires, and
  /// when the server reports an expired token — refreshes are invisible to
  /// the user. [userInfo] is ignored when set: your server passes it when it
  /// issues the token.
  ///
  /// Without it the SDK uses the legacy mode (API key + [userId]), which a
  /// project can disable in Rivium Console.
  final ChatTokenProvider? tokenProvider;

  /// Off by default: `sendMessage` without network throws, as before. When
  /// on, a message that cannot be sent because of the network (no network,
  /// timeout, server busy) is kept and sent when the connection is back, in
  /// order and never twice; `sendMessage` returns it as a pending message
  /// (`isPending == true`). See `onMessageSent` and `onMessageFailed`.
  final bool queueOfflineMessages;

  /// With [queueOfflineMessages]: where the queue is kept. In memory by
  /// default; pass your own [OutboxStore] to keep it across app restarts.
  final OutboxStore? outboxStore;

  const RiviumChatConfig({
    required this.apiKey,
    required this.userId,
    this.userInfo,
    this.fileUploader,
    this.tokenProvider,
    this.httpTimeout = const Duration(seconds: 15),
    this.queueOfflineMessages = false,
    this.outboxStore,
  });

  /// Throws an [ArgumentError] when [apiKey] or [userId] is empty.
  void validate() {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'API key is required');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID is required');
    }
  }

  /// Creates a copy with modified fields.
  RiviumChatConfig copyWith({
    String? apiKey,
    String? userId,
    Map<String, dynamic>? userInfo,
    FileUploader? fileUploader,
    ChatTokenProvider? tokenProvider,
    Duration? httpTimeout,
    bool? queueOfflineMessages,
    OutboxStore? outboxStore,
  }) {
    return RiviumChatConfig(
      apiKey: apiKey ?? this.apiKey,
      userId: userId ?? this.userId,
      userInfo: userInfo ?? this.userInfo,
      fileUploader: fileUploader ?? this.fileUploader,
      tokenProvider: tokenProvider ?? this.tokenProvider,
      httpTimeout: httpTimeout ?? this.httpTimeout,
      queueOfflineMessages: queueOfflineMessages ?? this.queueOfflineMessages,
      outboxStore: outboxStore ?? this.outboxStore,
    );
  }
}
