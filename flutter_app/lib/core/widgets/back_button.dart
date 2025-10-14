import 'package:flutter/material.dart';
import '../../navigation/nav.dart';

class BackButtonCompact extends StatelessWidget {
  const BackButtonCompact({
    super.key,
    this.onPressed,
    this.size = 36,
    this.twoPaneKey, // optional for nested shell handling
  });

  final VoidCallback? onPressed;
  final double size;
  final GlobalKey<NavigatorState>? twoPaneKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;
    final overlay = scheme.primary.withValues(alpha: 0.12);

    void defaultBack() {
      // Centralised navigation logic
      Nav.back(context, twoPaneKey: twoPaneKey);
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
