// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screens & scaffolding
import 'auth/screens/login_screen.dart';
import 'content/screens/pages.dart';
import 'content/screens/user_screen.dart';
import 'content/screens/help_screen.dart';
import 'core/widgets/app_scaffold.dart';
import 'core/widgets/breadcrumb_bar.dart';
import 'core/widgets/left_pane_nested.dart';
import 'core/widgets/two_panel_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// (Optional) Riverpod auth stream — keep if used elsewhere in your app
final authStateProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// Notify GoRouter when a stream emits (so redirect runs), without rebuilding router
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Stable navigator keys (created once, reused)
final _rootKey = GlobalKey<NavigatorState>();
final _scaffoldShellKey = GlobalKey<NavigatorState>();
final _twoPaneShellKey = GlobalKey<NavigatorState>();

// Mark which routes need auth (public by default)
bool _needsAuth(GoRouterState s) {
  final loc = s.matchedLocation;
  if (loc.startsWith('/user-details')) return true;
  // add more protected prefixes as you wire them:
  // if (loc.startsWith('/team-admin')) return true;
  return false;
}

// Provide ONE GoRouter instance that does NOT rebuild on auth changes
final goRouterProvider = Provider<GoRouter>((ref) {
  // Important: do NOT ref.watch(authStateProvider) here.
  // Rebuilding this provider would recreate the router and duplicate GlobalKeys.
  final refreshListenable = RouterRefresh(FirebaseAuth.instance.authStateChanges());
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    // Public landing page
    initialLocation: '/enquiries',
    // Re-run redirect when auth changes, without rebuilding the router
    refreshListenable: refreshListenable,

    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final goingToLogin = state.matchedLocation == '/login';

      // If trying to access a protected route while logged out → go to /login
      if (!isLoggedIn && _needsAuth(state) && !goingToLogin) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }

      // If logged in and on /login → bounce back to ?from or default
      if (isLoggedIn && goingToLogin) {
        final back = state.uri.queryParameters['from'];
        return back ?? '/enquiries';
      }

      // Otherwise, no redirect
      return null;
    },

    routes: [
      // Public (no scaffold)
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LoginScreen(),
      ),

      // Outer shell: AppScaffold persists for all pages below
      ShellRoute(
        navigatorKey: _scaffoldShellKey,
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          // Inner shell: TwoPane layout for /enquiries/**
          ShellRoute(
            navigatorKey: _twoPaneShellKey,
            builder: (context, state, child) => TwoPaneShell(
              leftPane: LeftPaneNested(state: state),
              breadcrumb: BreadcrumbBar(state: state),
              child: child,
            ),
            routes: [
              GoRoute(
                path: '/enquiries',
                builder: (context, state) => const NoSelectionPage(),
                routes: [
                  GoRoute(
                    path: ':enquiryId',
                    builder: (context, state) => EnquiryDetailPage(
                      enquiryId: state.pathParameters['enquiryId']!,
                    ),
                    routes: [
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

          // Pages that replace the TwoPane (still inside AppScaffold)
          GoRoute(
            path: '/user-details',
            builder: (context, state) => const ClaimsScreen(),
          ),
          GoRoute(
            path: '/help',
            builder: (context, state) => const HelpFaqScreen(),
          ),
        ],
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// App root
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LeP8ssrAAAAAHuCNAA-tIXVzahLuskzGP7K-Si0'),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static Color parseHexColour(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff'); // add full alpha if #RRGGBB
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static final Color kSeed = parseHexColour('#209ED6'); // theme seed

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Rule Post',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kSeed,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kSeed,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
    );
  }
}
