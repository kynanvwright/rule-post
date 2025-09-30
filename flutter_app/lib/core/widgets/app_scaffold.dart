// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './colour_helper.dart';
import '../../auth/widgets/auth_service.dart';
enum _ProfileAction { profile, logout }

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title = 'Rule Post',
    this.subtitle = "the home of rule enquiries",
    this.maxWidth = 1600,
    this.tileAsset = 'assets/images/cup_logo2.jpg',
    this.banner,
    this.actions = const [],
    this.footer,
    this.bannerHeight = 128,     // 👈 master scale
    this.logoScale = 0.8,        // 0–1 of banner height
    this.titleScale = 0.26,      // font size = h * titleScale
    this.subtitleScale = 0.16,   // font size = h * subtitleScale
    this.iconScale = 0.34,       // icon size = h * iconScale (kept modest)
  });

  final Widget child;
  final String title;
  final String subtitle;
  final double maxWidth;
  final String tileAsset;
  final Widget? banner;
  final List<Widget> actions; // additional right-side actions (optional)
  final Widget? footer;

  // Proportions
  final double bannerHeight;
  final double logoScale;
  final double titleScale;
  final double subtitleScale;
  final double iconScale;

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
                          banner ??
                              _DefaultBanner(
                                title: title,
                                subtitle: subtitle,
                                actions: actions,
                                height: bannerHeight,
                                logoScale: logoScale,
                                titleScale: titleScale,
                                subtitleScale: subtitleScale,
                                iconScale: iconScale,
                              ),
                          // Page content
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
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
    required this.subtitle,
    this.actions = const [],
    this.height = 128,
    this.logoScale = 0.64,
    this.titleScale = 0.26,
    this.subtitleScale = 0.16,
    this.iconScale = 0.34,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final double height;

  final double logoScale;
  final double titleScale;
  final double subtitleScale;
  final double iconScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // final authService = AuthService();

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;

          // Derived metrics
          final padX = h * 0.125;               // ~16 @ 128
          final logoH = h * logoScale;          // defaults ~82 @ 128
          final gap = h * 0.2;                 // ~12 @ 128
          final titleSize = h * titleScale;     // ~33 @ 128
          final subtitleSize = h * subtitleScale; // ~20 @ 128
          final iconSize = h * iconScale;       // ~43 @ 128 (noticeably smaller than old)
          final minTap = 40.0;                  // keep good tap target

          return Container(
            padding: EdgeInsets.symmetric(horizontal: padX),
            decoration: BoxDecoration(
              // Clean: solid brand or subtle gradient
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primary.lighten(0.1)],
                // colors: [scheme.primary, scheme.primaryContainer],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: h * 0.06,
                  offset: Offset(0, h * 0.02),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Logo + Title/Sub
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => context.go('/enquiries?status=open'), // 👈 navigate home
                      borderRadius: BorderRadius.circular(h * 0.1),
                      child: Padding(
                        padding: EdgeInsets.all(h * 0.05), // keeps tap target comfy
                        child: Image.asset('assets/images/cup_logo.png', height: logoH),
                      ),
                    ),
                    SizedBox(width: gap),
                    // Title + subtitle
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                            fontSize: titleSize,
                            color: scheme.onPrimary,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: h * 0.02),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                            fontSize: subtitleSize,
                            color: scheme.onPrimary.withValues(alpha: 0.9),
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // Optional extra actions (kept modest)
                ...actions.map(
                  (w) => Padding(
                    padding: EdgeInsets.only(left: gap * 0.7),
                    child: IconTheme.merge(
                      data: IconThemeData(size: iconSize * 0.82, color: scheme.onPrimary),
                      child: w,
                    ),
                  ),
                ),

                SizedBox(width: gap),

                // Right: Help icon
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  child: IconButton(
                    tooltip: 'Help',
                    onPressed: () => context.go('/help'),
                    icon: Icon(Icons.help_outline, color: scheme.onPrimary, size: iconSize),
                    padding: EdgeInsets.zero,
                    splashRadius: (iconSize + minTap) / 4,
                  ),
                ),

                SizedBox(width: gap * 0.6),

                // Right: Account icon (popup)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  child: PopupMenuButton<_ProfileAction>(
                    tooltip: 'Account',
                    icon: Icon(Icons.account_circle, color: scheme.onPrimary, size: iconSize),
                    onSelected: (value) async {
                      switch (value) {
                        case _ProfileAction.profile:
                          if (context.mounted) context.go('/user-details');
                          break;
                        case _ProfileAction.logout:
                          await AuthService().signOut();
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
