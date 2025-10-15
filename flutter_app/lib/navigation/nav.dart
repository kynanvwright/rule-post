// nav.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// ------ internals ------------------------------------------------------------

void _next(VoidCallback f) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => f());

String _currentPath(BuildContext c) =>
    GoRouter.of(c).routeInformationProvider.value.uri.toString();

bool _same(BuildContext c, String target) => _currentPath(c) == target;

/// ------ public API -----------------------------------------------------------

class Nav {
  /// Replace stack with the enquiries list (your "Home")
  static void goHome(BuildContext c) => _next(() => GoRouter.of(c).go('/enquiries'));

  /// Open FAQ / Account / Login (adjust to taste)
  static void pushHelp(BuildContext c) {
    const t = '/help';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  static void pushAccount(BuildContext c) {
    const t = '/user-details';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  static void goLogin(BuildContext c) => _next(() => GoRouter.of(c).go('/login'));

  /// ---- Enquiries drill-down (TwoPane shell) --------------------------------

  static void pushEnquiry(BuildContext c, String enquiryId) {
    final t = '/enquiries/$enquiryId';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  static void pushResponse(BuildContext c, String enquiryId, String responseId) {
    final t = '/enquiries/$enquiryId/responses/$responseId';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  /// Explicitly exit selection back to the list route.
  static void exitToList(BuildContext c) => goHome(c);

  /// Back behaviour:
  /// 1) Pop the TwoPane shell if provided and it can pop
  /// 2) Else pop the router if it can pop
  /// 3) Else, if we're under /enquiries/*, normalise to /enquiries
  static void back(
    BuildContext c, {
    GlobalKey<NavigatorState>? twoPaneKey,
  }) {
    final pane = twoPaneKey?.currentState;
    if (pane?.canPop() ?? false) {
      pane!.pop();
      return;
    }

    final r = GoRouter.of(c);
    if (r.canPop()) {
      r.pop();
      return;
    }

    final loc = _currentPath(c);
    if (loc.startsWith('/enquiries') && loc != '/enquiries') {
      goHome(c);
      return;
    }
    // otherwise: nothing to do (we're already at top-level)
  }
}
