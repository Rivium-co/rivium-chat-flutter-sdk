import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Data for a link preview.
class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? favicon;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.favicon,
  });

  /// Creates preview data from Open Graph metadata.
  factory LinkPreviewData.fromOpenGraph(Map<String, String> metadata, String url) {
    return LinkPreviewData(
      url: url,
      title: metadata['og:title'] ?? metadata['title'],
      description: metadata['og:description'] ?? metadata['description'],
      imageUrl: metadata['og:image'],
      siteName: metadata['og:site_name'],
      favicon: metadata['favicon'],
    );
  }

  bool get hasContent => title != null || description != null || imageUrl != null;
}

/// A widget that displays a link preview with image, title, and description.
/// Similar to link previews in Telegram, WhatsApp, and Slack.
class LinkPreview extends StatelessWidget {
  /// The preview data to display.
  final LinkPreviewData data;

  /// Called when the preview is tapped.
  final VoidCallback? onTap;

  /// Called when the close button is tapped.
  final VoidCallback? onClose;

  /// Whether this preview is on the current user's message.
  final bool isMe;

  /// Whether to show the close button.
  final bool showCloseButton;

  /// Whether to show the image in large format.
  final bool largeImage;

  /// Border radius of the preview container.
  final BorderRadius? borderRadius;

  /// Maximum width of the preview.
  final double? maxWidth;

  const LinkPreview({
    super.key,
    required this.data,
    this.onTap,
    this.onClose,
    this.isMe = false,
    this.showCloseButton = false,
    this.largeImage = false,
    this.borderRadius,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!data.hasContent) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: largeImage ? _buildLargeLayout(context) : _buildCompactLayout(context),
      ),
    );
  }

  Widget _buildLargeLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large image
        if (data.imageUrl != null)
          AspectRatio(
            aspectRatio: 1.91 / 1, // Standard OG image ratio
            child: CachedNetworkImage(
              imageUrl: data.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),

        // Content
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Site name with favicon
              if (data.siteName != null || data.favicon != null)
                _buildSiteInfo(context),

              // Title
              if (data.title != null) ...[
                if (data.siteName != null) const SizedBox(height: 4),
                Text(
                  data.title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : null,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Description
              if (data.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  data.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Close button
              if (showCloseButton) _buildCloseButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail image
          if (data.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: data.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 60,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => Container(
                  width: 60,
                  height: 60,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Site name with favicon
                if (data.siteName != null || data.favicon != null)
                  _buildSiteInfo(context),

                // Title
                if (data.title != null) ...[
                  if (data.siteName != null) const SizedBox(height: 2),
                  Text(
                    data.title!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : null,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Description
                if (data.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.8)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Close button
          if (showCloseButton) _buildCloseButton(context),
        ],
      ),
    );
  }

  Widget _buildSiteInfo(BuildContext context) {
    return Row(
      children: [
        if (data.favicon != null) ...[
          CachedNetworkImage(
            imageUrl: data.favicon!,
            width: 14,
            height: 14,
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
        ],
        if (data.siteName != null)
          Text(
            data.siteName!.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          Icons.close,
          size: 18,
          color: isMe
              ? Colors.white.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A widget for displaying link previews while composing a message.
class LinkPreviewComposer extends StatelessWidget {
  /// The preview data to display.
  final LinkPreviewData? data;

  /// Whether the preview is loading.
  final bool isLoading;

  /// Called when the preview is removed.
  final VoidCallback? onRemove;

  const LinkPreviewComposer({
    super.key,
    this.data,
    this.isLoading = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading preview...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    if (data == null || !data!.hasContent) {
      return const SizedBox.shrink();
    }

    return LinkPreview(
      data: data!,
      showCloseButton: true,
      onClose: onRemove,
    );
  }
}

/// Utility to extract URLs from text.
class LinkExtractor {
  static final _urlPattern = RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  /// Extracts all URLs from the given text.
  static List<String> extractUrls(String text) {
    return _urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Extracts the first URL from the given text.
  static String? extractFirstUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }

  /// Checks if the text contains any URLs.
  static bool containsUrl(String text) {
    return _urlPattern.hasMatch(text);
  }
}
