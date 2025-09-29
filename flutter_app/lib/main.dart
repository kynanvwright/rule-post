// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart'; // <-- make sure this path is correct

// ─────────────────────────────────────────────────────────────────────────────
// Your app scaffolding & screens (replace these imports with your actual ones)
import 'auth/screens/login_screen.dart';
import 'content/screens/pages.dart';
import 'content/screens/user_screen.dart';
import 'content/screens/help_screen.dart';
import 'core/widgets/app_scaffold.dart';
import 'core/widgets/breadcrumb_bar.dart';
import 'core/widgets/left_pane_nested.dart';
import 'core/widgets/two_panel_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod: auth stream
final authStateProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// A small Listenable that notifies GoRouter whenever a stream emits
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

// Navigator keys
final _rootKey = GlobalKey<NavigatorState>();
final _scaffoldShellKey = GlobalKey<NavigatorState>();
final _twoPaneShellKey = GlobalKey<NavigatorState>();

// Riverpod: provide a GoRouter that reacts to auth changes
final goRouterProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final loggedIn = authAsync.valueOrNull != null;

  // Make router rebuild when auth changes
  final refreshListenable =
      RouterRefresh(FirebaseAuth.instance.authStateChanges());

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/enquiries',
    refreshListenable: refreshListenable,

    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn && !loggingIn) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }
      if (loggedIn && loggingIn) {
        final back = state.uri.queryParameters['from'];
        return back ?? '/enquiries';
      }
      return null;
    },

    routes: [
      // Public (no scaffold)
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LoginScreen(),
      ),

      // Outer shell: AppScaffold persists for all authenticated routes
      ShellRoute(
        navigatorKey: _scaffoldShellKey,
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          // Inner shell: TwoPane layout only for /enquiries/**
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

          // Pages that REPLACE the TwoPane (still inside AppScaffold)
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

  // ✅ Initialise Firebase *before* ProviderScope / any FirebaseAuth usage
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // Replace with your own helper if desired
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
