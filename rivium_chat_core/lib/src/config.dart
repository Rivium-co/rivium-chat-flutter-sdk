import 'dart:io';
import 'models/attachment.dart';

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

/// Configuration for the RiviumChat SDK.
class RiviumChatConfig {
  /// Base URL for the RiviumChat REST API.
  static const String baseUrl = 'https://chat.rivium.co';

  /// WebSocket URL for Centrifugo connection.
  static const String centrifugoUrl =
      'wss://ws-chat.rivium.co/connection/websocket';

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

  /// Optional custom user info to include in Centrifugo token.
  final Map<String, dynamic>? userInfo;

  /// Optional file uploader callback for sending attachments.
  final FileUploader? fileUploader;

  const RiviumChatConfig({
    required this.apiKey,
    required this.userId,
    this.userInfo,
    this.fileUploader,
    this.httpTimeout = const Duration(seconds: 15),
  });

  /// Creates a copy with modified fields.
  RiviumChatConfig copyWith({
    String? apiKey,
    String? userId,
    Map<String, dynamic>? userInfo,
    FileUploader? fileUploader,
    Duration? httpTimeout,
  }) {
    return RiviumChatConfig(
      apiKey: apiKey ?? this.apiKey,
      userId: userId ?? this.userId,
      userInfo: userInfo ?? this.userInfo,
      fileUploader: fileUploader ?? this.fileUploader,
      httpTimeout: httpTimeout ?? this.httpTimeout,
    );
  }
}
