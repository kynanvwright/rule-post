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
  static void goHelp(BuildContext c) {
    const t = '/help';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  static void goAccount(BuildContext c) {
    const t = '/user-details';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  static void goLogin(BuildContext c) => _next(() => GoRouter.of(c).go('/login'));

  /// ---- Enquiries drill-down (TwoPane shell) --------------------------------

  static void goEnquiry(BuildContext c, String enquiryId) {
    final t = '/enquiries/$enquiryId';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  static void goResponse(BuildContext c, String enquiryId, String responseId) {
    final t = '/enquiries/$enquiryId/responses/$responseId';
    if (_same(c, t)) return;
    _next(() => GoRouter.of(c).go(t));
  }

  /// Explicitly exit selection back to the list route.
  static void exitToList(BuildContext c) => goHome(c);

}
