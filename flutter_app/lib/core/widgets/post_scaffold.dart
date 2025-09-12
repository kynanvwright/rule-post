import 'package:flutter/material.dart';

// import 'app_scaffold.dart';

/// A 3-pane layout that plugs into your GeneralAppScaffold.
/// Left:   categories / filters
/// Centre: list of items for the selected category
/// Right:  detail panel (empty state when null)
class PostScaffold extends StatelessWidget {
  const PostScaffold({
    super.key,
    required this.title,
    required this.leftPane,
    required this.centerPane,
    required this.rightPane,
    this.minWidth = 1024,
    this.leftWidth = 260,
    this.centerWidth = 420,
  });

  final String title;
  final Widget leftPane;
  final Widget centerPane;
  final Widget? rightPane;

  /// When width < minWidth, collapses left pane into a Drawer and stacks centre/right.
  final double minWidth;

  /// Fixed widths for desktop-ish layouts.
  final double leftWidth;
  final double centerWidth;

  @override
  Widget build(BuildContext context) {
    // You already have a GeneralAppScaffold; we wrap inside it.
    // Replace `Scaffold` below with your GeneralAppScaffold if it exposes a `child`.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < minWidth;

            if (isNarrow) {
              // Mobile/tablet: left pane moves to Drawer; centre + right stack.
              return _NarrowLayout(
                title: title,
                drawerContent: leftPane,
                centerPane: centerPane,
                rightPane: rightPane,
              );
            }

            // Wide: three columns with subtle separators.
            return Row(
              children: [
                SizedBox(
                  width: leftWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: Divider.createBorderSide(context),
                      ),
                    ),
                    child: leftPane,
                  ),
                ),
                SizedBox(
                  width: centerWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: Divider.createBorderSide(context),
                      ),
                    ),
                    child: centerPane,
                  ),
                ),
                // Right expands to fill remaining space
                Expanded(
                  child: rightPane ??
                      const Center(
                        child: Text(
                          'Select an enquiry to view details',
                          style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.title,
    required this.drawerContent,
    required this.centerPane,
    required this.rightPane,
  });

  final String title;
  final Widget drawerContent;
  final Widget centerPane;
  final Widget? rightPane;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // You likely already have a banner in GeneralAppScaffold; this is a mobile fallback.
      ),
      drawer: Drawer(
        child: SafeArea(child: drawerContent),
      ),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: Divider.createBorderSide(context),
                ),
              ),
              child: centerPane,
            ),
          ),
          Expanded(
            child: rightPane ??
                const Center(
                  child: Text(
                    'Select an enquiry to view details',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
