// flutter_app/lib/content/widgets/section_card.dart
import 'package:flutter/material.dart';

// used in detail scaffold to get a consistent card style
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    required this.child,
  });

  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // if there's a team colour assigned, overlay it on the default card colour
          if (backgroundColor != null)
            Positioned.fill(child: ColoredBox(color: backgroundColor!)),
          // default card
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null || trailing != null) ...[
                  Row(
                    children: [
                      if (title != null)
                        Text(title!, style: theme.textTheme.titleMedium),
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                  const Divider(height: 16),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
