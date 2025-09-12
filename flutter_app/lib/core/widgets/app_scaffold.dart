// app_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../auth/widgets/auth_service.dart';
enum _ProfileAction { profile, logout }


class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title = 'Rule Post',
    this.maxWidth = 1600,
    this.tileAsset = 'assets/images/cup_logo2.jpg',
    this.banner,
    this.actions = const [],
    this.footer,
  });

  final Widget child;
  final String title;
  final double maxWidth;
  final String tileAsset;      // subtle tiling background
  final Widget? banner;        // a brand/header bar
  final List<Widget> actions;  // right-side header actions
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      body: Stack(
        children: [
          // Background (colour + repeating tile)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6FB),
              image: DecorationImage(
                image: AssetImage(tileAsset),
                repeat: ImageRepeat.repeat,
                opacity: 0.06,
              ),
            ),
          ),

          // Centered app canvas
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.all(isNarrow ? 12 : 24),
                  child: Material(
                    elevation: 10,
                    color: Theme.of(context).colorScheme.surface,
                    shadowColor: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header / banner
                          banner ?? _DefaultBanner(title: title, actions: actions),

                          // Page content
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context).colorScheme.surface,
                                    Theme.of(context).colorScheme.surface.withOpacity(0.97),
                                  ],
                                ),
                              ),
                              child: child,
                            ),
                          ),

                          // Optional footer
                          if (footer != null) footer!,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner({required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;
  

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final _authService = AuthService();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Image.asset('assets/images/cup_logo.png', height: 28),
              const SizedBox(width: 12),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: scheme.onPrimary)),
            ],
          ),
          const Spacer(),
          ...actions,

          // Profile menu
          PopupMenuButton<_ProfileAction>(
            tooltip: 'Account',
            icon: Icon(Icons.account_circle, color: scheme.onPrimary),
            onSelected: (value) async {
              switch (value) {
                case _ProfileAction.profile:
                  // TODO: Navigator.pushNamed(context, '/profile');
                  break;
                case _ProfileAction.logout:
                  await _authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _ProfileAction.profile,
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _ProfileAction.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
