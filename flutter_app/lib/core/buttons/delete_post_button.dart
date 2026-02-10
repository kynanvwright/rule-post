// flutter_app/lib/core/buttons/delete_post_button.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/post_apis.dart';
import 'package:rule_post/core/models/post_types.dart';
import 'package:rule_post/navigation/nav.dart';


/// Button to delete unpublished posts
class DeletePostButton extends StatelessWidget {
  const DeletePostButton({
    super.key,
    required this.type,
    required this.postId,
    this.parentIds,
  });

  final PostType type;
  final String postId;
  final List<String>? parentIds;

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text('Delete ${type.singular}?'),
        content: Text(
          'This action cannot be undone. The ${type.singular} will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    if (!context.mounted) return;

    await deletePost(
      context,
      type: type,
      postId: postId,
      parentIds: parentIds,
    );
    if (!context.mounted) return;

    // Navigate up to a valid page after deleting enquiries/responses.
    switch (type) {
      case PostType.enquiry:
        Nav.goHome(context);
        break;
      case PostType.response:
        final parents = parentIds;
        if (parents != null && parents.isNotEmpty) {
          Nav.goEnquiry(context, parents[0]);
        } else {
          Nav.goHome(context);
        }
        break;
      case PostType.comment:
        // stay on response detail page
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const tooltipText = 'Delete this draft';

    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;

    return Semantics(
      button: true,
      enabled: true,
      label: tooltipText,
      child: Tooltip(
        message: tooltipText,
        child: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: bg, // icon colour
          onPressed: () => _handleDelete(context),
          tooltip: tooltipText,
        ),
      ),
    );
  }
}
