// flutter_app/lib/content/widgets/header_block.dart
import 'package:flutter/material.dart';


// header content for the enquiry and response detail pages
class HeaderBlock extends StatelessWidget {
  const HeaderBlock({
    super.key,
    required this.headerLines,
    required this.subHeaderLines,
    this.trailing, // 👈 optional trailing widget
  });

  final List<String> headerLines;
  final List<String> subHeaderLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final headerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sub in subHeaderLines)
          Text(
            '$sub:',
            style: t.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        if (subHeaderLines.isNotEmpty) const SizedBox(height: 4),
        for (final line in headerLines) Text(line, style: t.titleLarge),
      ],
    );

    // 👇 If trailing is provided, wrap in Row; otherwise just show header text.
    return trailing == null ?
    headerColumn :
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: headerColumn),
        const SizedBox(width: 8),
        trailing!,
      ],
    );
  }
}