import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackButtonCompact extends StatelessWidget {
  const BackButtonCompact({
    super.key,
    this.onPressed,
    this.size = 36,
  });

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;
    final overlay = scheme.primary.withValues(alpha: 0.12);

    void defaultBack() {
      if (Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/enquiries');
      }
    }

    return FilledButton(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(CircleBorder()),
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStatePropertyAll(fg),
        overlayColor: WidgetStatePropertyAll(overlay),
        minimumSize: WidgetStatePropertyAll(Size.square(size)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      ),
      onPressed: onPressed ?? defaultBack,
      child: const Icon(Icons.arrow_back, size: 20),
    );
  }
}
