import 'dart:async';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Local imports
import 'auth/screens/login_screen.dart';
import 'content/screens/pages.dart';
import 'content/screens/user_screen.dart';
import 'core/widgets/app_scaffold.dart';
import 'core/widgets/breadcrumb_bar.dart';
import 'core/widgets/left_pane_nested.dart';
import 'core/widgets/two_panel_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(webProvider: ReCaptchaV3Provider('6LeP8ssrAAAAAHuCNAA-tIXVzahLuskzGP7K-Si0'));

  runApp(const ProviderScope(child: MyApp()));
}


/// Small helper so GoRouter re-evaluates redirects on auth changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}


final router = GoRouter(
  initialLocation: '/enquiries?status=open',
  refreshListenable:
      GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final isLogin = state.matchedLocation == '/login';
    final wantsAuth = state.matchedLocation.startsWith('/enquiries');

    // If not logged in and trying to hit an authed route → go to login with return url
    if (!loggedIn && wantsAuth) {
      final from = Uri.encodeComponent(state.uri.toString()); // preserves query + path
      return '/login?from=$from';
    }

    // If logged in and on /login → bounce to intended page (or default)
    if (loggedIn && isLogin) {
      final from = state.uri.queryParameters['from'];
      return from != null ? Uri.decodeComponent(from) : '/enquiries?status=open';
    }

    return null;
  },
  routes: [
    // Public route
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // Authenticated shell: two-pane layout
    ShellRoute(
      builder: (context, state, child) {
        return AppScaffold(
          title: 'RulePost',
          child: TwoPaneShell(
            leftPane: LeftPaneNested(state: state),
            breadcrumb: BreadcrumbBar(state: state),
            child: child,
          ),
        );
      },
      routes: [
        // Level 1: enquiries list + detail
        GoRoute(
          path: '/enquiries',
          builder: (context, state) => const NoSelectionPage(), // optional
          routes: [
            GoRoute(
              path: ':enquiryId',
              builder: (context, state) => EnquiryDetailPage(
                enquiryId: state.pathParameters['enquiryId']!,
              ),
              routes: [
                // Level 2: responses
                GoRoute(
                  path: 'responses',
                  builder: (context, state) => const NoSelectionPage(),
                  routes: [
                    GoRoute(
                      path: ':responseId',
                      builder: (context, state) => ResponseDetailPage(
                        enquiryId: state.pathParameters['enquiryId']!,
                        responseId: state.pathParameters['responseId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // User Details
    GoRoute(
      path: '/user-details',
      builder: (context, state) => const AppScaffold(
        title: 'RulePost',
        child: ClaimsScreen(),
      ),
    ),
  ],
);


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Rule Enquiries App',
      routerConfig: router,
    );
  }
}
