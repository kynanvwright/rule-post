// flutter_app/lib/core/navigation/page_fade.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


// use in main.dart if you want pages to fade in on transition
CustomTransitionPage fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (ctx, anim, secAnim, child) =>
        FadeTransition(opacity: anim, child: child),
    child: child,
  );
}
