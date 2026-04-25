/// Represents a file attachment in a message.
class Attachment {
  final String url;
  final String? mimeType;
  final String? name;
  final int? size;

  const Attachment({
    required this.url,
    this.mimeType,
    this.name,
    this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      url: json['url'] as String,
      mimeType: json['mimeType'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (mimeType != null) 'mimeType': mimeType,
      if (name != null) 'name': name,
      if (size != null) 'size': size,
    };
  }

  Attachment copyWith({
    String? url,
    String? mimeType,
    String? name,
    int? size,
  }) {
    return Attachment(
      url: url ?? this.url,
      mimeType: mimeType ?? this.mimeType,
      name: name ?? this.name,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attachment &&
        other.url == url &&
        other.mimeType == mimeType &&
        other.name == name &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(url, mimeType, name, size);

  @override
  String toString() {
    return 'Attachment(url: $url, mimeType: $mimeType, name: $name, size: $size)';
  }
}
