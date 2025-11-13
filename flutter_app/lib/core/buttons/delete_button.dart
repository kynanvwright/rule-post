// flutter_app/lib/core/buttons/delete_button.dart
import 'dart:async';
import 'package:flutter/material.dart';


// button to delete data using the frontend
class DeleteButton extends StatefulWidget {
  const DeleteButton({
    super.key,
    required this.labelText,
    required this.onConfirmDelete, // your deletion logic
    this.icon = Icons.delete_outline,
    this.tooltipText = 'Delete',
    this.onPressedTitle = 'Delete?',
    this.onPressedText = 'This action cannot be undone.',
    this.onPressedButtonText = 'Delete',
  });

  final String labelText;
  final Future<void> Function() onConfirmDelete;
  final IconData icon;
  final String tooltipText;
  final String onPressedTitle;
  final String onPressedText;
  final String onPressedButtonText;

  @override
  State<DeleteButton> createState() => _DeleteButtonState();
}


class _DeleteButtonState extends State<DeleteButton> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = scheme.primary;
    final fgColor = scheme.onPrimary;

    return Tooltip(
      key: _tooltipKey,
      message: widget.tooltipText,
      child: FilledButton.icon(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(bgColor),
          foregroundColor: WidgetStatePropertyAll(fgColor),
          overlayColor: WidgetStatePropertyAll(
            (scheme.onError).withValues(alpha: 0.08),
          ),
        ),
        icon: Icon(widget.icon, color: fgColor),
        label: Text(widget.labelText),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(widget.onPressedTitle),
              content: widget.onPressedText.isNotEmpty
                ? Text(widget.onPressedText)
                : null,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(scheme.error),
                    foregroundColor: WidgetStatePropertyAll(scheme.onError),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(widget.onPressedButtonText),
                ),
              ],
            ),
          );

          if (ok == true && mounted) {
            await widget.onConfirmDelete();
          }
        },
      ),
    );
  }
}