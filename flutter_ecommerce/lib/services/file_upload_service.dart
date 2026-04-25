import 'dart:io';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:path/path.dart' as path;

/// Example file upload service
///
/// In a real app, you would upload to your storage service:
/// - AWS S3
/// - Firebase Storage
/// - Cloudflare R2
/// - Supabase Storage
/// - Your own server
///
/// RiviumChat never stores files - it only stores the URL you return.
class FileUploadService {
  /// Upload a file and return the result
  ///
  /// This is passed to RiviumChatConfig.fileUploader
  static Future<FileUploadResult> uploadFile(File file) async {
    // Get file info
    final fileName = path.basename(file.path);
    final fileSize = await file.length();
    final mimeType = _getMimeType(fileName);

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TODO: Replace this with your actual upload implementation
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //
    // Example with AWS S3:
    // ```dart
    // final s3Client = S3Client(region: 'us-east-1', credentials: ...);
    // final key = 'chat-attachments/${DateTime.now().millisecondsSinceEpoch}/$fileName';
    // await s3Client.putObject(bucket: 'my-bucket', key: key, body: file.readAsBytesSync());
    // final url = 'https://my-bucket.s3.amazonaws.com/$key';
    // ```
    //
    // Example with Firebase Storage:
    // ```dart
    // final ref = FirebaseStorage.instance.ref('chat-attachments/$fileName');
    // await ref.putFile(file);
    // final url = await ref.getDownloadURL();
    // ```
    //
    // Example with Supabase Storage:
    // ```dart
    // final response = await supabase.storage.from('attachments').upload(fileName, file);
    // final url = supabase.storage.from('attachments').getPublicUrl(fileName);
    // ```
    //
    // For this demo, we'll simulate an upload with a placeholder URL
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // In demo mode, use a placeholder image service
    final isImage = mimeType?.startsWith('image/') ?? false;
    final url = isImage
        ? 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/800/600'
        : 'https://example.com/files/$fileName';

    return FileUploadResult(
      url: url,
      mimeType: mimeType,
      name: fileName,
      size: fileSize,
    );
  }

  /// Get MIME type from file extension
  static String? _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';

      // Documents
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      // Other
      case '.txt':
        return 'text/plain';
      case '.zip':
        return 'application/zip';
      case '.mp4':
        return 'video/mp4';
      case '.mp3':
        return 'audio/mpeg';

      default:
        return 'application/octet-stream';
    }
  }
}
