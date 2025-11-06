// flutter_app/lib/core/widgets/delete_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteButton extends StatefulWidget {
  const DeleteButton({
    super.key,
    required this.labelText,
    required this.onConfirmDelete, // your deletion logic
    this.locked = false,
    this.tooltipWhenLocked = 'You can’t delete this right now.',
  });

  final String labelText;
  final Future<void> Function() onConfirmDelete;
  final bool locked;
  final String tooltipWhenLocked;

  @override
  State<DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<DeleteButton> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;

    // Destructive palette using Material 3 error colours
    final bgColor = widget.locked ? bg.withValues(alpha: 0.55) : bg;
    final fgColor = widget.locked ? fg.withValues(alpha: 0.55) : fg;

    return Tooltip(
      key: _tooltipKey,
      message: widget.locked ? widget.tooltipWhenLocked : 'Delete',
      child: FilledButton.icon(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(bgColor),
          foregroundColor: WidgetStatePropertyAll(fgColor),
          overlayColor: WidgetStatePropertyAll(
            (widget.locked ? scheme.onSurface : scheme.onError)
                .withValues(alpha: 0.08),
          ),
        ),
        icon: Icon(widget.locked ? Icons.lock_outline : Icons.delete_outline, color: fgColor),
        label: Text(widget.labelText),
        onPressed: () async {
          if (widget.locked) {
            final s = _tooltipKey.currentState;
            if (s is TooltipState) s.ensureTooltipVisible();
            return;
          }

          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete?'),
              content: const Text('This action cannot be undone.'),
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
                  child: const Text('Delete'),
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

Future<int> deleteByQuery({
  required Query query,
  int pageSize = 200, // Firestore SDK limit ~ 1000; keep it modest
}) async {
  var deleted = 0;
  Query next = query.limit(pageSize);

  while (true) {
    final snap = await next.get();
    if (snap.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    deleted += snap.docs.length;

    // If you need pagination based on a field, add startAfter docs here.
    // For simple deletes, we can just loop — the next.get() will see fewer docs.
    if (snap.docs.length < pageSize) break;
  }
  return deleted;
}