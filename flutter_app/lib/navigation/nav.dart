// nav.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../debug/nav_log.dart';

void _next(VoidCallback f) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => f());

String _currentPath(BuildContext c) =>
    GoRouter.of(c).routeInformationProvider.value.uri.toString();

class Nav {
  /// Replace stack with the enquiries list (your "Home")
  static void goHome(BuildContext c) => _goOnNext(c, '/enquiries', tag: 'goHome');

  static void goHelp(BuildContext c) => _goOnNext(c, '/help', tag: 'goHelp', skipIfSame: true);

  static void goAccount(BuildContext c) => _goOnNext(c, '/user-details', tag: 'goAccount', skipIfSame: true);

  static void goLogin(BuildContext c) => _goOnNext(c, '/login', tag: 'goLogin');

  static void goEnquiry(BuildContext c, String enquiryId) =>
      _goOnNext(c, '/enquiries/$enquiryId', tag: 'goEnquiry', skipIfSame: true);

  static void goResponse(BuildContext c, String enquiryId, String responseId) =>
      _goOnNext(c, '/enquiries/$enquiryId/responses/$responseId', tag: 'goResponse', skipIfSame: true);

  static void exitToList(BuildContext c) => goHome(c);

  // ---------------- internals ----------------
  static bool _navInFlight = false;

  static void _goOnNext(BuildContext c, String path, {required String tag, bool skipIfSame = false}) {
    final seq = NavLog.nextSeq();
    final cur = _currentPath(c);
    if (skipIfSame && cur == path) {
      NavLog.p('[$seq][$tag] no-op (already at target) "$path"');
      return;
    }
    NavLog.p('[$seq][$tag] schedule next-frame nav: "$cur" -> "$path" (inFlight=$_navInFlight)');

    // _next(() {
      final sw = NavLog.sw('[$seq][$tag] execute go("$path")');
      _goOnce(c, path, seq: seq, tag: tag);
      NavLog.end(sw, '[$seq][$tag] execute go("$path")');
    // });
  }

  static void _goOnce(BuildContext c, String path, {required int seq, required String tag}) {
    final current = _currentPath(c);
    if (current == path) {
      NavLog.p('[$seq][$tag] goOnce: already at "$path" -> no-op');
      return;
    }
    if (_navInFlight) {
      NavLog.p('[$seq][$tag] goOnce: blocked (inFlight=true) for "$path"');
      return;
    }
    _navInFlight = true;
    NavLog.p('[$seq][$tag] goOnce: ENTER (from="$current" -> to="$path")');

    try {
      GoRouter.of(c).go(path);
    } catch (e, st) {
      NavLog.p('[$seq][$tag] goOnce: ERROR $e\n$st');
      rethrow;
    } finally {
      // Release on next microtask; collapses double taps / handlers
      Future.microtask(() {
        _navInFlight = false;
        NavLog.p('[$seq][$tag] goOnce: EXIT (released inFlight=false)');
      });
    }
  }
}
