// flutter_app/lib/content/widgets/author_tag.dart

/// Returns a text suffix for the author team (e.g., "(NZL)").
/// Returns empty string if authorTeam is null.
String formatAuthorSuffix(String? authorTeam) {
  if (authorTeam == null || authorTeam.isEmpty) {
    return '';
  }
  return ' ($authorTeam)';
}
