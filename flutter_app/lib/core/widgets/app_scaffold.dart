// app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/user_detail.dart';
import './colour_helper.dart';
import '../../auth/widgets/auth_service.dart';
import '../../navigation/nav.dart';

enum _Bp { phone, tablet, desktop }
_Bp _bp(double w) {
  if (w < 600) return _Bp.phone;
  if (w < 1024) return _Bp.tablet;
  return _Bp.desktop;
}


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
    final width = MediaQuery.of(context).size.width;
    final bp = _bp(width);

    // Pick a comfy height per breakpoint if caller didn't override.
    final effectiveBannerHeight = switch (bp) {
      _Bp.phone  => (bannerHeight * 0.70).clamp(56, 96),   // smaller, but tappable
      _Bp.tablet => bannerHeight,                          // as-is
      _Bp.desktop=> bannerHeight,                          // as-is
    }.toDouble();

    return Scaffold(
      body: Stack(
        children: [
          // Background (colour + repeating tile)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF121212)
                  : const Color(0xFFF7F6FB),
              image: DecorationImage(
                image: AssetImage(tileAsset),
                repeat: ImageRepeat.repeat,
                opacity: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.06,
                colorFilter: Theme.of(context).brightness == Brightness.dark
                    ? ColorFilter.mode(Colors.black.withValues(alpha: 0.45), BlendMode.darken)
                    : null,
              ),
            ),
          ),


          // Centered app canvas
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.all(bp == _Bp.phone ? 8 : 24),
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
                                height: effectiveBannerHeight,
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

class _DefaultBanner extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final bp = _bp(w);
          final h = constraints.maxHeight;

          // Tighter padding/gaps on phones
          final padX = bp == _Bp.phone ? 12.0 : h * 0.125;
          final gap  = bp == _Bp.phone ? 8.0  : h * 0.2;

          // Derived metrics
          final logoH = h * logoScale;          // defaults ~82 @ 128
          final titleSize = h * titleScale;     // ~33 @ 128
          final subtitleSize = h * subtitleScale; // ~20 @ 128
          final iconSize = h * iconScale;       // ~43 @ 128 (noticeably smaller than old)
          final minTap = 40.0;                  // keep good tap target

          // Optionally hide subtitle at very small widths
          final showSubtitle = !(bp == _Bp.phone && w < 380);

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
                      // LEFT CLUSTER — allow it to grow/shrink
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!(bp == _Bp.phone && w < 340)) // optional: hide logo on ultra-narrow
                              InkWell(
                                onTap: () => Nav.goHome(context),
                                borderRadius: BorderRadius.circular(h * 0.1),
                                child: Padding(
                                  padding: EdgeInsets.all(bp == _Bp.phone ? h * 0.03 : h * 0.05),
                                  child: Image.asset('assets/images/cup_logo.png',
                                      height: bp == _Bp.phone ? (logoH.clamp(32, 56)) : logoH),
                                ),
                              ),
                            SizedBox(width: gap),

                            // Title & (maybe) subtitle — make sure this part can truncate
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: InkWell(
                                  onTap: () => Nav.goHome(context),
                                  borderRadius: BorderRadius.circular(h * 0.06), // light rounding for nicer splash
                                  splashColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08),
                                  highlightColor: Colors.transparent,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: h * 0.06), // keeps tap target comfy
                                    child: Column(
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
                                          softWrap: false,
                                        ),
                                        if (showSubtitle) ...[
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
                                            softWrap: false,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),

                      SizedBox(width: gap), // a fixed spacer is OK

                      // RIGHT CLUSTER — only as wide as its contents
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Inline actions on tablet/desktop, overflow menu on phone
                          if (bp != _Bp.phone) ...actions.map(
                            (w) => Padding(
                              padding: EdgeInsets.only(left: gap * 0.7),
                              child: IconTheme.merge(
                                data: IconThemeData(size: iconSize * 0.82, color: scheme.onPrimary),
                                child: w,
                              ),
                            ),
                          ) else if (actions.isNotEmpty) ...[
                            MenuAnchor(
                              builder: (context, controller, _) => IconButton(
                                tooltip: 'More',
                                icon: Icon(Icons.more_vert, color: scheme.onPrimary, size: iconSize * 0.9),
                                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                                padding: EdgeInsets.zero,
                                splashRadius: (iconSize + minTap) / 4,
                              ),
                              // if your actions are icons, consider mapping to text labels here
                              menuChildren: actions.map((w) => MenuItemButton(child: w)).toList(),
                            ),
                            SizedBox(width: gap * 0.4),
                          ],

                          // Help
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            child: IconButton(
                              tooltip: 'Help',
                              onPressed: () => Nav.pushHelp(context),
                              icon: Icon(Icons.help_outline, color: scheme.onPrimary, size: iconSize),
                              padding: EdgeInsets.zero,
                              splashRadius: (iconSize + minTap) / 4,
                            ),
                          ),

                          SizedBox(width: gap * 0.6),

                          // Account
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            child: MenuAnchor(
                              builder: (context, controller, _) => IconButton(
                                tooltip: 'Account',
                                icon: Icon(Icons.account_circle, color: scheme.onPrimary, size: iconSize),
                                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                                padding: EdgeInsets.zero,
                                splashRadius: (iconSize + minTap) / 4,
                              ),
                              menuChildren: [
                                if (isLoggedIn) ...[
                                  MenuItemButton(
                                    leadingIcon: Icon(Icons.person),
                                    child: Text("Profile"),
                                    onPressed: () => Nav.pushAccount(context),
                                  ),
                                  MenuItemButton(
                                    leadingIcon: const Icon(Icons.logout),
                                    child: const Text("Sign Out"),
                                    onPressed: () async {
                                      await AuthService().signOut();
                                      if (context.mounted) {
                                        Nav.goHome(context);
                                      }
                                    },
                                  ),
                                ] else
                                  MenuItemButton(
                                    leadingIcon: const Icon(Icons.login),
                                    child: const Text("Sign In"),
                                    onPressed: () => Nav.goLogin(context),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]
            ),
          );
        },
      ),
    );
  }
}
