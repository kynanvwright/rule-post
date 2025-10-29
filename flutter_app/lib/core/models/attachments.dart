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
    final storagePath = (map['storagePath'] ?? map['path']) as String?;
    return TempAttachment(
      name: (map['name'] ?? '') as String,
      storagePath: storagePath ?? '',
      size: map['size'] is num ? (map['size'] as num).toInt() : null,
      contentType: map['contentType'] as String?,
    );
  }
}
