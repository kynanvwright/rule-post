// flutter_app/lib/content/widgets/mark_unread_button.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/admin_apis.dart';


// (Legacy) Used by admins to mark posts as unread for testing
class MarkUnreadButton extends StatefulWidget {
  const MarkUnreadButton({
    super.key,
    required this.enquiryId,
    this.responseId,
    this.commentId,
  });

  final String enquiryId;
  final String? responseId;
  final String? commentId;

  @override
  State<MarkUnreadButton> createState() => _MarkUnreadButtonState();
}


class _MarkUnreadButtonState extends State<MarkUnreadButton> {
  @override
  Widget build(BuildContext context) {
    const labelText = 'Admin: Mark As Unread';

    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;

    return Semantics(
      button: true,
      enabled: true,
      label: labelText,
      child: FilledButton.icon(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(bg),
          foregroundColor: WidgetStatePropertyAll(fg),
          overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: 0.08),
          ),
        ),
        icon: Icon(Icons.mark_as_unread_outlined, color: fg),
        label: const Text(labelText),
        onPressed: () async {
          await markPostUnread(
            context,
            widget.enquiryId,
            widget.responseId,
            widget.commentId,
          );
        },
      ),
    );
  }
}