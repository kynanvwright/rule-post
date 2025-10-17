import 'package:flutter/material.dart';

/// -------------------- COLLAPSIBLE TEXT (for comments) --------------------
class ListTileCollapsibleText extends StatefulWidget {
  const ListTileCollapsibleText(
    this.text, {
    super.key,
    this.maxLines = 3,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.showCollapsedHint = true,
    this.tileColor, // NEW: mimic ListTile.tileColor
  });

  final String text;
  final int maxLines;
  final EdgeInsetsGeometry contentPadding;
  final bool showCollapsedHint;
  final Color? tileColor; // NEW

  @override
  State<ListTileCollapsibleText> createState() => _ListTileCollapsibleTextState();
}

class _ListTileCollapsibleTextState extends State<ListTileCollapsibleText>
    with TickerProviderStateMixin {
  bool _expanded = false;
  bool _overflows = false;

  void _checkOverflow(
    BoxConstraints c,
    TextStyle style,
    TextDirection dir,
    EdgeInsets resolvedPad,
  ) {
    final maxWidth = c.maxWidth - resolvedPad.horizontal;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: dir,
    )..layout(maxWidth: maxWidth > 0 ? maxWidth : 0);
    _overflows = tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listTileTheme = ListTileTheme.of(context);
    final dir = Directionality.of(context);
    final textStyle = theme.textTheme.bodyMedium!;
    final iconColor = listTileTheme.iconColor ?? theme.iconTheme.color;
    final resolvedPad = widget.contentPadding.resolve(dir);

    return LayoutBuilder(
      builder: (context, constraints) {
        _checkOverflow(constraints, textStyle, dir, resolvedPad);

        return Material(
          // NEW: allow background colour like ListTile.tileColor
          color: widget.tileColor ?? Colors.transparent,
          child: InkWell(
            onTap: _overflows ? () => setState(() => _expanded = !_expanded) : null,
            // DEPRECATION: MaterialStateProperty -> WidgetStateProperty
            overlayColor: WidgetStateProperty.resolveWith((states) {
              final base = theme.colorScheme.onSurface;
              // DEPRECATION: withOpacity -> withValues(alpha: ...)
              if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
                return base.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return base.withValues(alpha: 0.04);
              }
              return null;
            }),
            child: Padding(
              padding: resolvedPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.text,
                            style: textStyle,
                            maxLines: _expanded ? null : widget.maxLines,
                            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (_overflows) ...[
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 160),
                          turns: _expanded ? 0.5 : 0.0,
                          child: Icon(Icons.expand_more, size: 24, color: iconColor),
                        ),
                      ],
                    ],
                  ),
                  if (_overflows && !_expanded && widget.showCollapsedHint) ...[
                    const SizedBox(height: 4),
                    Text(
                      "…",
                      style: textStyle.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Semantics(
                    button: true,
                    expanded: _expanded,
                    label: _expanded ? 'Collapse' : 'Expand',
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
