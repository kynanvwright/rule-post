// app_scaffold.dart
import 'package:flutter/material.dart';

import 'app_banner.dart';
import 'screen_width.dart';


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
    debugPrint('🔍 AppScaffold rebuild');
    final width = MediaQuery.of(context).size.width;
    final bp = getBreakpoint(width);

    // Pick a comfy height per breakpoint if caller didn't override.
    final effectiveBannerHeight = switch (bp) {
      Breakpoint.phone  => (bannerHeight * 0.70).clamp(56, 96),   // smaller, but tappable
      Breakpoint.tablet => bannerHeight,                          // as-is
      Breakpoint.desktop=> bannerHeight,                          // as-is
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
                  padding: EdgeInsets.all(bp == Breakpoint.phone ? 8 : 24),
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
                              AppBanner(
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
