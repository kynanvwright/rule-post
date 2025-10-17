import 'package:flutter/material.dart';


class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? Colors.blueGrey).withValues(alpha: 0.12);
    final fg = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final borderCol = (color ?? Colors.black12).withValues(alpha: 0.2);

    return Container(
      constraints: const BoxConstraints(minHeight: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // tweak radius
          side: BorderSide(color: borderCol),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
        softWrap: true,
      ),
    );
  }
}
