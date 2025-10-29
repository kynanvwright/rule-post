class TempAttachment {
  final String name;
  final String storagePath;
  final int? size;
  final String? contentType;

  TempAttachment({
    required this.name,
    required this.storagePath,
    this.size,
    this.contentType,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'storagePath': storagePath,
    if (size != null) 'size': size,
    if (contentType != null) 'contentType': contentType,
  };

  factory TempAttachment.fromMap(Map<String, dynamic> map) {
    return TempAttachment(
      name: map['name'] as String,
      storagePath: map['url'] as String,
      size: map['size'] as int?,
      contentType: map['contentType'] as String?,
    );
  }
}

