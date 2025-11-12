// lib/core/models/post_types.dart


enum PostType {
  enquiry('enquiry', 'enquiries', 'enquiries_temp'),
  response('response', 'responses', 'responses_temp'),
  comment('comment', 'comments', 'comments_temp');

  const PostType(this.singular, this.plural, this.tempFolder);

  final String singular;
  final String plural;
  final String tempFolder;

  /// Optional convenience
  static PostType? tryParse(String s) {
    final lower = s.toLowerCase();
    for (final t in values) {
      if (t.singular == lower || t.plural == lower) return t;
    }
    return null;
  }
}