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
}
