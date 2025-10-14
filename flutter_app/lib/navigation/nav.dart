// nav.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// ------ internals ------------------------------------------------------------

void _next(VoidCallback f) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => f());

String _currentPath(BuildContext c) =>
    GoRouter.of(c).routeInformationProvider.value.uri.toString();

bool _same(BuildContext c, String target) => _currentPath(c) == target;

bool _isLogin(String path) => path.startsWith('/login');

/// ------ capped push ----------------------------------------------------------

class _NavDepth {
  int depth = 0;
  final int maxDepth;
  _NavDepth(this.maxDepth);
}
final _navDepth = _NavDepth(3);

void _pushCapped(BuildContext c, String path) {
  final r = GoRouter.of(c);

  // Never stack login; always replace
  if (_isLogin(path)) {
    r.replace(path);
    _navDepth.depth = 0;
    return;
  }

  if (_navDepth.depth < _navDepth.maxDepth) {
    r.push(path);
    _navDepth.depth++;
  } else {
    r.go(path);             // replace stack when over cap
    _navDepth.depth = 0;
  }
}

/// ------ public API -----------------------------------------------------------

class Nav {
  /// Replace stack with the enquiries list (your "Home")
  static void goHome(BuildContext c) =>
      _next(() { GoRouter.of(c).go('/enquiries'); _navDepth.depth = 0; });

  /// Non-auth pages you may want stacked (capped)
  static void pushHelp(BuildContext c) {
    const t = '/help';
    if (_same(c, t)) return;
    _next(() => _pushCapped(c, t));
  }

  static void pushAccount(BuildContext c) {
    const t = '/user-details';
    if (_same(c, t)) return;
    _next(() => _pushCapped(c, t));
  }

  /// Login should not appear in back history → replace
  static void goLogin(BuildContext c) =>
      _next(() { GoRouter.of(c).replace('/login'); _navDepth.depth = 0; });

  /// ---- Enquiries drill-down (TwoPane shell) --------------------------------

  static void pushEnquiry(BuildContext c, String enquiryId) {
    final t = '/enquiries/$enquiryId';
    if (_same(c, t)) return;
    _next(() => _pushCapped(c, t));
  }

  static void pushResponse(BuildContext c, String enquiryId, String responseId) {
    final t = '/enquiries/$enquiryId/responses/$responseId';
    if (_same(c, t)) return;
    _next(() => _pushCapped(c, t));
  }

  static void exitToList(BuildContext c) => goHome(c);

  /// --- Back logic ------------------------------------------------------------
  /// Returns true if it performed a back action.
  static bool back(
    BuildContext c, {
    GlobalKey<NavigatorState>? twoPaneKey,
  }) {
    final pane = twoPaneKey?.currentState;
    if (pane?.canPop() ?? false) {
      pane!.pop();
      // inner pane pop doesn't change outer depth
      return true;
    }

    final r = GoRouter.of(c);
    if (r.canPop()) {
      r.pop();
      _navDepth.depth = (_navDepth.depth - 1).clamp(0, _navDepth.maxDepth);
      return true;
    }

    final loc = _currentPath(c);
    if (loc.startsWith('/enquiries') && loc != '/enquiries') {
      goHome(c);
      return true;
    }
    return false;
  }

  /// Compute whether a back action would do anything (for greying out buttons).
  static bool canGoBack(
    BuildContext c, {
    GlobalKey<NavigatorState>? twoPaneKey,
  }) {
    final pane = twoPaneKey?.currentState;
    if (pane?.canPop() ?? false) return true;

    final r = GoRouter.of(c);
    if (r.canPop()) return true;

    final loc = _currentPath(c);
    if (loc.startsWith('/enquiries') && loc != '/enquiries') return true;

    return false;
  }
}
