import 'package:flutter/material.dart';

/// Two-pane layout with four explicit slots (left/right headers + contents).
/// Headers are forced to the same height so dividers and content align nicely.
class TwoPaneFourSlot extends StatefulWidget {
  const TwoPaneFourSlot({
    super.key,
    // Four explicit slots
    required this.leftHeader,
    required this.leftContent,
    required this.rightHeader,
    required this.rightContent,

    // Layout controls (same spirit as before)
    this.initialLeftWidth = 320,
    this.minLeftWidth = 300,
    this.maxLeftWidth = 520,
    this.collapseBreakpoint = 820, // below this, left becomes a drawer
    this.tightBreakpoint = 600,    // below this, we gently scale content
    this.minRightWidth = 320,      // if tighter than this, scaling kicks in
    this.enableScaleOnTight = true,

    // Header cosmetics
    this.headerPadding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.showDividerBelowHeaders = true,

    // Collapsed-mode helpers
    this.injectHamburgerInCollapsedHeader = true,
    this.drawerSafeArea = true,

    // Advanced: equalise header heights even in collapsed mode (usually not needed)
    this.equaliseInCollapsedMode = false,

    // Alignment of header contents within the equalised box
    this.headerAlignment = Alignment.centerLeft,
    this.leftHeaderAlignment = Alignment.centerLeft,
    this.rightHeaderAlignment = Alignment.center,
  });

  // Four slots
  final Widget leftHeader;
  final Widget leftContent;
  final Widget rightHeader;
  final Widget rightContent;

  // Layout
  final double initialLeftWidth;
  final double minLeftWidth;
  final double maxLeftWidth;
  final double collapseBreakpoint;
  final double tightBreakpoint;
  final double minRightWidth;
  final bool enableScaleOnTight;

  // Styling
  final EdgeInsets headerPadding;
  final bool showDividerBelowHeaders;

  // Collapsed mode
  final bool injectHamburgerInCollapsedHeader;
  final bool drawerSafeArea;

  // Equalisation behaviour in collapsed mode
  final bool equaliseInCollapsedMode;

  // Visual alignment of header content inside the fixed-height header
  final AlignmentGeometry headerAlignment;
  final AlignmentGeometry? leftHeaderAlignment;
  final AlignmentGeometry? rightHeaderAlignment;

  @override
  State<TwoPaneFourSlot> createState() => _TwoPaneFourSlotState();
}

class _TwoPaneFourSlotState extends State<TwoPaneFourSlot> {
  late double _leftWidth;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Shared max header height (including padding). Both headers listen to this.
  final ValueNotifier<double> _headerMaxHeight = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _leftWidth =
        widget.initialLeftWidth.clamp(widget.minLeftWidth, widget.maxLeftWidth);
  }

  @override
  void dispose() {
    _headerMaxHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final isCollapsed = totalW < widget.collapseBreakpoint;

        if (isCollapsed) {
          // Drawer mode (left stack in Drawer, right stack vertical)
          final scale = _computeScaleForRight(totalW);

          final rightHeader = widget.equaliseInCollapsedMode
              ? _EqualisedHeader(
                  padding: widget.headerPadding,
                  alignment: widget.rightHeaderAlignment ?? widget.headerAlignment,
                  sharedMax: _headerMaxHeight,
                  child: Row(
                    children: [
                      if (widget.injectHamburgerInCollapsedHeader)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          tooltip: 'Open list',
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                      Expanded(child: widget.rightHeader),
                    ],
                  ),
                )
              : Padding(
                  padding: widget.headerPadding,
                  child: Row(
                    children: [
                      if (widget.injectHamburgerInCollapsedHeader)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          tooltip: 'Open list',
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                      Expanded(child: widget.rightHeader),
                    ],
                  ),
                );

          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              width: widget.initialLeftWidth
                  .clamp(widget.minLeftWidth, widget.maxLeftWidth),
              child: TwoPaneScope(
                closeDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
                child: widget.drawerSafeArea
                  ? SafeArea(
                      child: _LeftStack(
                        widget: widget,
                        sharedMax: widget.equaliseInCollapsedMode
                            ? _headerMaxHeight
                            : null,
                      ),
                    )
                  : _LeftStack(
                      widget: widget,
                      sharedMax:
                          widget.equaliseInCollapsedMode ? _headerMaxHeight : null,
                    ),
              ),
            ),
            body: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: rightHeader,
                ),
                if (widget.showDividerBelowHeaders) const Divider(height: 1),
                Expanded(child: _maybeScaled(scale, child: widget.rightContent)),
              ],
            ),
          );
        }

        // Side-by-side mode with resizable left pane
        _leftWidth =
            _leftWidth.clamp(widget.minLeftWidth, widget.maxLeftWidth);

        final rightW = totalW - _leftWidth - 1; // divider thickness
        final scale = _computeScaleForRight(rightW);

        return Scaffold(
          body: TwoPaneScope(
            closeDrawer: () {}, // no-op in side-by-side mode
            child: Row(
              children: [
                // Left pane
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.minLeftWidth,
                    maxWidth: widget.maxLeftWidth,
                  ),
                  child: SizedBox(
                    width: _leftWidth,
                    child: Column(
                      children: [
                        _EqualisedHeader(
                          padding: widget.headerPadding,
                          alignment: widget.headerAlignment,
                          sharedMax: _headerMaxHeight,
                          child: widget.leftHeader,
                        ),
                        if (widget.showDividerBelowHeaders)
                          const Divider(height: 1),
                        Expanded(child: widget.leftContent),
                      ],
                    ),
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
                      _EqualisedHeader(
                        padding: widget.headerPadding,
                        alignment: widget.rightHeaderAlignment ?? widget.headerAlignment,
                        sharedMax: _headerMaxHeight,
                        child: widget.rightHeader,
                      ),
                      if (widget.showDividerBelowHeaders)
                        const Divider(height: 1),
                      Expanded(child: _maybeScaled(scale, child: widget.rightContent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _computeScaleForRight(double rightWidth) {
    if (!widget.enableScaleOnTight) return 1.0;
    if (rightWidth >= widget.minRightWidth) return 1.0;

    // Linearly scale down to ~0.9 between minRightWidth and tightBreakpoint,
    // and to ~0.85 if extremely tight.
    const floor = 0.85;
    const gentle = 0.90;

    if (rightWidth <= widget.tightBreakpoint) {
      final t = (rightWidth / widget.tightBreakpoint).clamp(0.0, 1.0);
      return floor + (gentle - floor) * t;
    }
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

/// Collapsed-mode left stack used inside Drawer or left pane.
/// If [sharedMax] is provided, header is equalised; otherwise it uses natural height.
class _LeftStack extends StatelessWidget {
  const _LeftStack({required this.widget, this.sharedMax});
  final TwoPaneFourSlot widget;
  final ValueNotifier<double>? sharedMax;

  @override
  Widget build(BuildContext context) {
    final header = sharedMax == null
        ? Padding(
            padding: widget.headerPadding,
            child: widget.leftHeader,
          )
        : _EqualisedHeader(
            padding: widget.headerPadding,
            alignment: widget.headerAlignment,
            sharedMax: sharedMax!,
            child: widget.leftHeader,
          );

    return Column(
      children: [
        header,
        if (widget.showDividerBelowHeaders) const Divider(height: 1),
        Expanded(child: widget.leftContent),
      ],
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
          width: 8,
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

/// Equalises header height across peers:
/// - Measures its own (padded) height after layout,
/// - Updates [sharedMax] to the maximum seen,
/// - Rebuilds with a fixed SizedBox(height: sharedMax.value) to hard-equalise.
///
/// Notes:
/// - We measure including [padding], so both sides should use the same padding.
/// - [alignment] controls how the header content sits within the equalised box.
class _EqualisedHeader extends StatefulWidget {
  const _EqualisedHeader({
    required this.child,
    required this.padding,
    required this.alignment,
    required this.sharedMax,
  });

  final Widget child;
  final EdgeInsets padding;
  final AlignmentGeometry alignment;
  final ValueNotifier<double> sharedMax;

  @override
  State<_EqualisedHeader> createState() => _EqualisedHeaderState();
}

class _EqualisedHeaderState extends State<_EqualisedHeader> {
  // We listen to sharedMax so this header rebuilds when the maximum changes.
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () => setState(() {});
    widget.sharedMax.addListener(_listener);
    // First layout pass may be unconstrained; schedule a measure.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  void didUpdateWidget(covariant _EqualisedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedMax != widget.sharedMax) {
      oldWidget.sharedMax.removeListener(_listener);
      widget.sharedMax.addListener(_listener);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportHeight());
  }

  @override
  void dispose() {
    widget.sharedMax.removeListener(_listener);
    super.dispose();
  }

  void _reportHeight() {
    final box = context.findRenderObject() as RenderBox?;
    final h = (box?.hasSize ?? false) ? box!.size.height : 0.0;
    if (h > 0 && h > widget.sharedMax.value) {
      widget.sharedMax.value = h;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.sharedMax.value > 0 ? widget.sharedMax.value : null;

    final content = Padding(
      padding: widget.padding,
      child: Align(
        alignment: widget.alignment,
        child: widget.child,
      ),
    );

    // If we already know the shared max, clamp to it; otherwise natural height.
    return target == null ? content : SizedBox(height: target, child: content);
  }
}

// Helps to close drawers when on skinny screen
class TwoPaneScope extends InheritedWidget {
  const TwoPaneScope({
    super.key,
    required this.closeDrawer,
    required super.child,
  });

  final VoidCallback closeDrawer;

  static TwoPaneScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TwoPaneScope>();

  @override
  bool updateShouldNotify(TwoPaneScope oldWidget) => false;
}
