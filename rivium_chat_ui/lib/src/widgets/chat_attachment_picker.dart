import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// Attachment type selected by the user.
enum AttachmentType {
  camera,
  gallery,
  video,
  file,
  location,
  contact,
}

/// Result of an attachment selection.
class AttachmentResult {
  final AttachmentType type;
  final File? file;
  final List<File>? files;
  final Map<String, dynamic>? metadata;

  const AttachmentResult({
    required this.type,
    this.file,
    this.files,
    this.metadata,
  });
}

/// A bottom sheet picker for chat attachments.
/// Supports camera, gallery, video, files, location, and contacts.
class ChatAttachmentPicker extends StatelessWidget {
  /// Called when an attachment is selected.
  final void Function(AttachmentResult result)? onAttachmentSelected;

  /// Whether to allow multiple file selection.
  final bool allowMultiple;

  /// Whether to show the camera option.
  final bool showCamera;

  /// Whether to show the gallery option.
  final bool showGallery;

  /// Whether to show the video option.
  final bool showVideo;

  /// Whether to show the file option.
  final bool showFile;

  /// Whether to show the location option.
  final bool showLocation;

  /// Whether to show the contact option.
  final bool showContact;

  /// Custom grid item builder.
  final Widget Function(BuildContext, AttachmentType, VoidCallback)?
      itemBuilder;

  /// Maximum image dimension for compression.
  final double maxImageDimension;

  /// Image quality for compression (0-100).
  final int imageQuality;

  /// Maximum file size in bytes (default 20MB).
  final int maxFileSize;

  const ChatAttachmentPicker({
    super.key,
    this.onAttachmentSelected,
    this.allowMultiple = false,
    this.showCamera = true,
    this.showGallery = true,
    this.showVideo = true,
    this.showFile = true,
    this.showLocation = false,
    this.showContact = false,
    this.itemBuilder,
    this.maxImageDimension = 1920,
    this.imageQuality = 85,
    this.maxFileSize = 20 * 1024 * 1024,
  });

  /// Shows the attachment picker as a modal bottom sheet.
  static Future<AttachmentResult?> show(
    BuildContext context, {
    bool allowMultiple = false,
    bool showCamera = true,
    bool showGallery = true,
    bool showVideo = true,
    bool showFile = true,
    bool showLocation = false,
    bool showContact = false,
    double maxImageDimension = 1920,
    int imageQuality = 85,
    int maxFileSize = 20 * 1024 * 1024,
  }) async {
    AttachmentResult? result;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatAttachmentPicker(
        allowMultiple: allowMultiple,
        showCamera: showCamera,
        showGallery: showGallery,
        showVideo: showVideo,
        showFile: showFile,
        showLocation: showLocation,
        showContact: showContact,
        maxImageDimension: maxImageDimension,
        imageQuality: imageQuality,
        maxFileSize: maxFileSize,
        onAttachmentSelected: (r) {
          result = r;
          Navigator.pop(context);
        },
      ),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = <_AttachmentOption>[];

    if (showCamera) {
      items.add(_AttachmentOption(
        type: AttachmentType.camera,
        icon: Icons.camera_alt,
        label: 'Camera',
        color: Colors.red,
        onTap: () => _pickFromCamera(context),
      ));
    }

    if (showGallery) {
      items.add(_AttachmentOption(
        type: AttachmentType.gallery,
        icon: Icons.photo,
        label: 'Gallery',
        color: Colors.purple,
        onTap: () => _pickFromGallery(context),
      ));
    }

    if (showVideo) {
      items.add(_AttachmentOption(
        type: AttachmentType.video,
        icon: Icons.videocam,
        label: 'Video',
        color: Colors.pink,
        onTap: () => _pickVideo(context),
      ));
    }

    if (showFile) {
      items.add(_AttachmentOption(
        type: AttachmentType.file,
        icon: Icons.insert_drive_file,
        label: 'Document',
        color: Colors.indigo,
        onTap: () => _pickFile(context),
      ));
    }

    if (showLocation) {
      items.add(_AttachmentOption(
        type: AttachmentType.location,
        icon: Icons.location_on,
        label: 'Location',
        color: Colors.green,
        onTap: () => _pickLocation(context),
      ));
    }

    if (showContact) {
      items.add(_AttachmentOption(
        type: AttachmentType.contact,
        icon: Icons.person,
        label: 'Contact',
        color: Colors.blue,
        onTap: () => _pickContact(context),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Share',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            // Grid of options
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                physics: const NeverScrollableScrollPhysics(),
                children: items.map((item) {
                  if (itemBuilder != null) {
                    return itemBuilder!(context, item.type, item.onTap);
                  }
                  return _AttachmentGridItem(option: item);
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxImageDimension,
      maxHeight: maxImageDimension,
      imageQuality: imageQuality,
    );

    if (picked != null) {
      onAttachmentSelected?.call(AttachmentResult(
        type: AttachmentType.camera,
        file: File(picked.path),
      ));
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final picker = ImagePicker();

    if (allowMultiple) {
      final picked = await picker.pickMultiImage(
        maxWidth: maxImageDimension,
        maxHeight: maxImageDimension,
        imageQuality: imageQuality,
      );

      if (picked.isNotEmpty) {
        onAttachmentSelected?.call(AttachmentResult(
          type: AttachmentType.gallery,
          files: picked.map((p) => File(p.path)).toList(),
        ));
      }
    } else {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxImageDimension,
        maxHeight: maxImageDimension,
        imageQuality: imageQuality,
      );

      if (picked != null) {
        onAttachmentSelected?.call(AttachmentResult(
          type: AttachmentType.gallery,
          file: File(picked.path),
        ));
      }
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (picked != null) {
      final file = File(picked.path);
      final size = await file.length();

      if (size > maxFileSize) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Video too large (max ${_formatFileSize(maxFileSize)})',
              ),
            ),
          );
        }
        return;
      }

      onAttachmentSelected?.call(AttachmentResult(
        type: AttachmentType.video,
        file: file,
      ));
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      if (allowMultiple) {
        final files = <File>[];
        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            final file = File(platformFile.path!);
            final size = await file.length();
            if (size <= maxFileSize) {
              files.add(file);
            }
          }
        }
        if (files.isNotEmpty) {
          onAttachmentSelected?.call(AttachmentResult(
            type: AttachmentType.file,
            files: files,
          ));
        }
      } else {
        final platformFile = result.files.single;
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          final size = await file.length();

          if (size > maxFileSize) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'File too large (max ${_formatFileSize(maxFileSize)})',
                  ),
                ),
              );
            }
            return;
          }

          onAttachmentSelected?.call(AttachmentResult(
            type: AttachmentType.file,
            file: file,
          ));
        }
      }
    }
  }

  void _pickLocation(BuildContext context) {
    // Location picking requires platform-specific implementation
    // This is a placeholder that returns a mock location
    onAttachmentSelected?.call(const AttachmentResult(
      type: AttachmentType.location,
      metadata: {
        'latitude': 0.0,
        'longitude': 0.0,
        'address': 'Location sharing not implemented',
      },
    ));
  }

  void _pickContact(BuildContext context) {
    // Contact picking requires platform-specific implementation
    // This is a placeholder
    onAttachmentSelected?.call(const AttachmentResult(
      type: AttachmentType.contact,
      metadata: {
        'name': 'Contact sharing not implemented',
      },
    ));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _AttachmentOption {
  final AttachmentType type;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _AttachmentGridItem extends StatelessWidget {
  final _AttachmentOption option;

  const _AttachmentGridItem({required this.option});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: option.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: option.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              option.icon,
              color: option.color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            option.label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
