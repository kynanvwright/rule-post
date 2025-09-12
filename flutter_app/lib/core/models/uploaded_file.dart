class UploadedFile {
  final String name;
  final String url;

  UploadedFile({required this.name, required this.url});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
    };
  }

  static UploadedFile fromMap(Map<String, dynamic> map) {
    return UploadedFile(
      name: map['name'] ?? '',
      url: map['url'] ?? '',
    );
  }
}
