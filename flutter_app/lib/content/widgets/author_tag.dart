// flutter_app/lib/content/widgets/author_tag.dart
import 'package:flutter/material.dart';


/// Displays a small chip showing the author/team of a post.
/// Typically used in post headers or metadata sections for admin visibility.
class AuthorTag extends StatelessWidget {
  const AuthorTag({
    required this.authorTeam,
    super.key,
  });

  /// The team name to display (e.g., "Ferrari", "RedBull", "RC")
  final String authorTeam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Subtle background; slightly muted
    final bgColor = isDark 
      ? Colors.grey.shade700 
      : Colors.grey.shade200;
    
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
    );

    return Chip(
      label: Text(
        'By $authorTeam',
        style: textStyle,
      ),
      avatar: const Icon(
        Icons.person,
        size: 16,
      ),
      backgroundColor: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: theme.dividerColor,
        width: 0.5,
      ),
    );
  }
}
