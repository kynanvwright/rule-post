import 'package:flutter/material.dart';

class TwoPaneShell extends StatefulWidget {
  const TwoPaneShell({
    super.key,
    required this.leftPane,
    required this.child,
    required this.breadcrumb,
    this.initialLeftWidth = 360,
    this.minLeftWidth = 260,
    this.maxLeftWidth = 520,
    this.collapseBreakpoint = 820,   // below this, left becomes a drawer
    this.tightBreakpoint = 600,      // below this, we gently scale content
    this.minRightWidth = 320,        // if tighter than this, scaling kicks in
    this.enableScaleOnTight = true,
  });

  final Widget leftPane;      // list at current level
  final Widget child;         // detail for current selection (or empty)
  final Widget breadcrumb;    // shows path

  final double initialLeftWidth;
  final double minLeftWidth;
  final double maxLeftWidth;
  final double collapseBreakpoint;
  final double tightBreakpoint;
  final double minRightWidth;
  final bool enableScaleOnTight;

  @override
  State<TwoPaneShell> createState() => _TwoPaneShellState();
}

class _TwoPaneShellState extends State<TwoPaneShell> {
  late double _leftWidth;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _leftWidth = widget.initialLeftWidth.clamp(
      widget.minLeftWidth, widget.maxLeftWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final isCollapsed = totalW < widget.collapseBreakpoint;

        // Drawer mode on narrow viewports
        if (isCollapsed) {
          final scale = _computeScaleForRight(totalW);
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              width: widget.initialLeftWidth
                  .clamp(widget.minLeftWidth, widget.maxLeftWidth),
              child: SafeArea(child: widget.leftPane),
            ),
            body: Column(
              children: [
                // Top bar with hamburger + breadcrumb
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu),
                          tooltip: 'Open list',
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        Expanded(child: widget.breadcrumb),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _maybeScaled(scale, child: widget.child),
                ),
              ],
            ),
          );
        }

        // Side-by-side mode with resizable left pane
        // Clamp left width if window changed drastically.
        _leftWidth = _leftWidth.clamp(
          widget.minLeftWidth, widget.maxLeftWidth,
        );

        final rightW = totalW - _leftWidth - 1; // minus divider
        final scale = _computeScaleForRight(rightW);

        return Scaffold(
          body: Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: widget.minLeftWidth,
                  maxWidth: widget.maxLeftWidth,
                ),
                child: SizedBox(
                  width: _leftWidth,
                  child: widget.leftPane,
                ),
              ),

              // Draggable divider
              _DragHandle(
                onDrag: (dx) {
                  setState(() {
                    _leftWidth = (_leftWidth + dx)
                        .clamp(widget.minLeftWidth, widget.maxLeftWidth);
                  });
                },
              ),

              // Right pane
              Expanded(
                child: Column(
                  children: [
                    widget.breadcrumb,
                    const Divider(height: 1),
                    Expanded(child: _maybeScaled(scale, child: widget.child)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _computeScaleForRight(double rightWidth) {
    if (!widget.enableScaleOnTight) return 1.0;
    if (rightWidth >= widget.minRightWidth) return 1.0;

    // Linearly scale down to ~0.9 between minRightWidth and tightBreakpoint,
    // and to ~0.85 if extremely tight. Tweak to taste.
    final floor = 0.85;
    final gentle = 0.90;

    if (rightWidth <= widget.tightBreakpoint) {
      // Map [0 .. tightBreakpoint] -> [floor .. gentle]
      final t = (rightWidth / widget.tightBreakpoint).clamp(0.0, 1.0);
      return floor + (gentle - floor) * t;
    }
    // Map [tightBreakpoint .. minRightWidth] -> [gentle .. 1.0]
    final t = ((rightWidth - widget.tightBreakpoint) /
            (widget.minRightWidth - widget.tightBreakpoint))
        .clamp(0.0, 1.0);
    return gentle + (1.0 - gentle) * t;
  }

  Widget _maybeScaled(double scale, {required Widget child}) {
    if (scale >= 0.999) return child;
    return Align(
      alignment: Alignment.topLeft,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: scale,
        child: child,
      ),
    );
  }
}

/// A thin draggable vertical handle with hover feedback.
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.onDrag});
  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Container(
          width: 8, // fat hit area, but we render a 1px line inside
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
