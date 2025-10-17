// nav.dart
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

Uri _currentUri(BuildContext c) =>
    GoRouter.of(c).routeInformationProvider.value.uri;

bool _samePath(Uri a, Uri b) => a.path == b.path;

String _normPath(String path) {
  final p = path.startsWith('/') ? path : '/$path';
  return (p.length > 1 && p.endsWith('/')) ? p.substring(0, p.length - 1) : p;
}

void _callNowOrMicrotask(void Function() f) {
  // If we’re currently building/layout/painting, defer to a microtask
  // (faster than next frame, avoids "during build" issues).
  final phase = SchedulerBinding.instance.schedulerPhase;
  switch (phase) {
    case SchedulerPhase.idle:
      f(); // safe to call immediately
      break;
    default:
      scheduleMicrotask(f);
  }
}

class Nav {
  static bool _navInFlight = false;

  static void goHome(BuildContext c) => _goOnce(c, '/enquiries');
  static void goHelp(BuildContext c) => _goOnce(c, '/help');
  static void goLogin(BuildContext c) => _goOnce(c, '/login');
  static void goAccount(BuildContext c) => _goOnce(c, '/user-details');

  static void goEnquiry(BuildContext c, String enquiryId) =>
      _goOnce(c, '/enquiries/${Uri.encodeComponent(enquiryId)}');

  static void goResponse(BuildContext c, String enquiryId, String responseId) =>
      _goOnce(c, '/enquiries/${Uri.encodeComponent(enquiryId)}/responses/${Uri.encodeComponent(responseId)}');

  static void exitToList(BuildContext c) => goHome(c);

  // ---- internals ------------------------------------------------------------
  static void _goOnce(BuildContext c, String path) {
    if (_navInFlight) return;

    final target = Uri(path: _normPath(path));
    final current = _currentUri(c);
    if (_samePath(current, target)) return;

    _navInFlight = true;

    _callNowOrMicrotask(() {
      try {
        GoRouter.of(c).go(target.toString()); // immediate hop
      } finally {
        // collapse rapid taps/handlers without delaying a frame
        scheduleMicrotask(() => _navInFlight = false);
      }
    });
  }
}
