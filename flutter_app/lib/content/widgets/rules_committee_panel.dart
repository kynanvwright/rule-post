import 'package:flutter/material.dart';

/// A single admin action (button) definition.
class AdminAction {
  const AdminAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? tooltip;
  final bool enabled;
}

class AdminCard extends StatefulWidget {
  const AdminCard({
    super.key,
    this.title = 'Rules Committee Panel',
    required this.actions,
    this.initiallyExpanded = false,
    this.requireArming = true,
    this.armLabel = 'Enable admin actions',
    this.compact = false,
    this.buttonMinWidth = 140,
    this.buttonMinHeight = 40,
    this.titleColour,
    this.boldTitle = true,
  });

  final String title;
  final List<AdminAction> actions;
  final bool initiallyExpanded;

  /// When true, shows a switch that must be turned on before buttons activate.
  final bool requireArming;
  final String armLabel;

  final bool compact;
  final double buttonMinWidth;
  final double buttonMinHeight;
  final Color? titleColour;
  final bool boldTitle;

  @override
  State<AdminCard> createState() =>
      _AdminCardState();
}

class _AdminCardState
    extends State<AdminCard> {
  bool _armed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    final titleStyle = base?.copyWith(
      color: widget.titleColour ?? base.color,
      fontWeight: widget.boldTitle ? FontWeight.bold : base.fontWeight,
    );

    final spacing = widget.compact ? 8.0 : 12.0;

    return Card(
      child: Theme( // tighten ExpansionTile padding a bit
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          onExpansionChanged: (v) => setState(() {
            // Disarm when closing to prevent accidental taps later
            if (!v) _armed = false;
          }),
          title: Text(widget.title, style: titleStyle),
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (widget.requireArming)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(widget.armLabel),
                value: _armed,
                onChanged: (v) => setState(() => _armed = v),
              ),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: widget.actions.map((a) {
                final btn = FilledButton.icon(
                  onPressed:
                      (a.enabled && (!widget.requireArming || _armed))
                          ? a.onPressed
                          : null,
                  icon: Icon(a.icon ?? Icons.settings),
                  label: Text(a.label),
                );

                final wrapped = a.tooltip == null
                    ? btn
                    : Tooltip(message: a.tooltip!, child: btn);

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.buttonMinWidth,
                    minHeight: widget.buttonMinHeight,
                  ),
                  child: wrapped,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
