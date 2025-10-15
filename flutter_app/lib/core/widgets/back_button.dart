import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

class BackButtonCompact extends StatelessWidget {
  const BackButtonCompact({
    super.key,
    this.size = 32,
    this.smartFallback = false,
    this.tooltip = 'Back',
  });

  final double size;
  final bool smartFallback;
  final String tooltip;

  void _exactBrowserBack() {
    if (kIsWeb) {
      web.window.history.back();
    }
  }

  void _smartBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      _exactBrowserBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;
    return IconButton.filled(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back),
      iconSize: size,
      onPressed: () => smartFallback ? _smartBack(context) : _exactBrowserBack(),
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(CircleBorder()),
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStatePropertyAll(fg),
        minimumSize: WidgetStatePropertyAll(Size.square(size)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      ),
    );
  }
}