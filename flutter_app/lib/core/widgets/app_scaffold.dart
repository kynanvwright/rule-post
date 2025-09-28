// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    this.bannerHeight = 128, // 👈 single control for header scale
  });

  final Widget child;
  final String title;
  final double maxWidth;
  final String tileAsset;
  final Widget? banner;
  final List<Widget> actions;
  final Widget? footer;
  final double bannerHeight; // 👈

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
                    shadowColor: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header / banner
                          banner ??
                              _DefaultBanner(
                                title: title,
                                actions: actions,
                                height: bannerHeight, // 👈 scale source
                              ),

                          // Page content
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context).colorScheme.surface,
                                    Theme.of(context)
                                        .colorScheme
                                        .surface
                                        .withValues(alpha: 0.97),
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
  const _DefaultBanner({
    required this.title,
    this.actions = const [],
    this.height = 128,
  });

  final String title;
  final List<Widget> actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final authService = AuthService();

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;

          // Proportional metrics (tweak these ratios to taste)
          final horizontalPad = h * 0.125; // 16 @ h=128
          final logoH = h * 0.72;          // 92 @ h=128
          final gap = h * 0.094;           // 12 @ h=128
          final titleSize = h * 0.28;      // ~36 @ h=128
          final iconSize = h * 0.5;        // 64 @ h=128
          final elevationBlur = h * 0.062; // 8 @ h=128
          final elevationOffsetY = h * 0.023; // 3 @ h=128

          return Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primaryContainer],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.15),
                  blurRadius: elevationBlur,
                  offset: Offset(0, elevationOffsetY),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left group: logo + title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/cup_logo.png', height: logoH),
                    SizedBox(width: gap),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                        fontSize: titleSize,
                        color: scheme.onPrimary,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const Spacer(), // 👈 ensures everything after is forced right

                // Optional actions
                ...actions.map((w) => Padding(
                      padding: EdgeInsets.only(left: gap * 0.7),
                      child: IconTheme.merge(
                        data: IconThemeData(size: iconSize * 0.72),
                        child: w,
                      ),
                    )),

                SizedBox(width: gap),

                // Account icon all the way right
                PopupMenuButton<_ProfileAction>(
                  tooltip: 'Account',
                  icon: Icon(Icons.account_circle, color: scheme.onPrimary),
                  iconSize: iconSize,
                  onSelected: (value) async {
                    switch (value) {
                      case _ProfileAction.profile:
                        if (context.mounted) context.go('/user-details');
                        break;
                      case _ProfileAction.logout:
                        await authService.signOut();
                        if (context.mounted) context.go('/login');
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ProfileAction.profile,
                      child: ListTile(
                        leading: Icon(Icons.person),
                        title: Text('Profile'),
                        dense: true,
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
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
        },
      ),
    );
  }
}
