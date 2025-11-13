import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'breadcrumb_bar.dart';
import '../buttons/back_button.dart';// 👈 import it

class RightPaneHeader extends ConsumerWidget {
  const RightPaneHeader({
    super.key,
    required this.state,
    this.onBack,
  });

  final GoRouterState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double sideWidth = 48;

    return Row(
      children: [
        // LEFT: compact back button
        SizedBox(
          width: sideWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: BackButtonCompact(),
          ),
        ),

        // CENTER: breadcrumb
        Expanded(
          child: Center(child: BreadcrumbBar(state: state)),
        ),

        // RIGHT: spacer for symmetry
        const SizedBox(width: sideWidth),
      ],
    );
  }
}
