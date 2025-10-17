import 'package:flutter/material.dart';

class HeaderBlock extends StatelessWidget {
  const HeaderBlock({
    super.key,
    required this.headerLines, 
    required this.subHeaderLines
  });
  final List<String> headerLines;
  final List<String> subHeaderLines;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sub in subHeaderLines) Text(
          '$sub:', 
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        if (subHeaderLines.isNotEmpty) const SizedBox(height: 4),
        for (final line in headerLines) Text(line, style: t.titleLarge),
      ],
    );
  }
}
