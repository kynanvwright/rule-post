// router.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import 'package:rule_post/content/screens/enquiry_detail_page.dart';
import 'package:rule_post/content/screens/help_screen.dart';
import 'package:rule_post/content/screens/no_selection_page.dart';
import 'package:rule_post/content/screens/response_detail_page.dart';
import 'package:rule_post/content/screens/user_screen.dart';
import 'package:rule_post/core/widgets/app_scaffold.dart';
import 'package:rule_post/core/widgets/left_pane_nested.dart';
import 'package:rule_post/core/widgets/right_pane_header.dart';
import 'package:rule_post/core/widgets/two_panel_shell.dart';


final rootKey = GlobalKey<NavigatorState>();
final scaffoldShellKey = GlobalKey<NavigatorState>();
final twoPaneShellKey = GlobalKey<NavigatorState>();

bool needsAuth(GoRouterState s) {
  final loc = s.matchedLocation;
  return loc.startsWith('/user-details');
}

class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}

GoRouter buildRouter() {
  final refreshListenable = RouterRefresh(FirebaseAuth.instance.authStateChanges());

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/enquiries',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final goingToLogin = state.matchedLocation == '/login';
      if (!isLoggedIn && needsAuth(state) && !goingToLogin) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }
      if (isLoggedIn && goingToLogin) {
        return state.uri.queryParameters['from'] ?? '/enquiries';
      }
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: scaffoldShellKey,
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          ShellRoute(
            navigatorKey: twoPaneShellKey,
            builder: (context, state, child) => TwoPaneFourSlot(
              leftHeader: LeftPaneHeader(),
              leftContent: LeftPaneNested(state: state),
              rightHeader: RightPaneHeader(state: state),
              rightContent: child,
            ),
            routes: [
              GoRoute(
                path: '/enquiries',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: ValueKey('page:${state.uri}'),
                  child: const NoSelectionPage(),
                ),
              ),
              GoRoute(
                path: '/enquiries/:enquiryId',
                pageBuilder: (context, state) {
                  final eid = state.pathParameters['enquiryId']!;
                  return NoTransitionPage(
                    key: ValueKey('enquiry:$eid'),
                    child: EnquiryDetailPage(enquiryId: eid),
                  );
                },
              ),
              GoRoute(
                path: '/enquiries/:enquiryId/responses/:responseId',
                pageBuilder: (context, state) {
                  final eid = state.pathParameters['enquiryId']!;
                  final rid = state.pathParameters['responseId']!;
                  return NoTransitionPage(
                    key: ValueKey('response:$eid:$rid'),
                    child: ResponseDetailPage(enquiryId: eid, responseId: rid),
                  );
                },
              ),
            ],
          ),
          GoRoute(path: '/user-details', builder: (context, state) => const ClaimsScreen()),
          GoRoute(path: '/help', builder: (context, state) => const HelpFaqScreen()),
        ],
      ),
    ],
  );
}
