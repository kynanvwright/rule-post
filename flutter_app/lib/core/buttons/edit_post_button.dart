//flutter_app/lib/content/widgets/edit_post_button.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/post_apis.dart';
import 'package:rule_post/core/models/attachments.dart';
import 'package:rule_post/core/models/post_payloads.dart';
import 'package:rule_post/core/models/post_types.dart';
import 'package:rule_post/core/models/types.dart' show NewPostPayload;
import 'package:rule_post/core/buttons/new_post_button.dart' show NewPostDialog;


/// Used to edit unpublished posts
class EditPostButton extends StatefulWidget {
  const EditPostButton({
    super.key,
    required this.type,
    required this.postId,
    this.parentIds,
    this.initialTitle,
    this.initialText,
    this.initialAttachments,
    required this.isPublished,
    this.initialCloseEnquiryOnPublish = false,
    this.initialEnquiryConclusion,
  });

  final PostType type;
  final String postId;
  final List<String>? parentIds;
  final String? initialTitle;
  final String? initialText;
  final List<Map<String, dynamic>>? initialAttachments;
  final bool isPublished;
  final bool initialCloseEnquiryOnPublish;
  final String? initialEnquiryConclusion;

  @override
  State<EditPostButton> createState() => _EditPostButtonState();
}


class _EditPostButtonState extends State<EditPostButton> {
  final _tooltipKey = GlobalKey<TooltipState>();
  EditAttachmentMap editAttachments = EditAttachmentMap();

  @override
  Widget build(BuildContext context) {
    const labelText = 'Edit';

    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;

    return Semantics(
      button: true,
      enabled: true, // SRs know it's unavailable, but we keep it focusable.
      label: labelText,
      child: Tooltip(
        key: _tooltipKey,
        triggerMode: TooltipTriggerMode.longPress, // hover still works on desktop
        message: 'Edit your draft ${widget.type.singular}',
        child: FilledButton.icon(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(bg),
            foregroundColor: WidgetStatePropertyAll(fg),
            overlayColor: WidgetStatePropertyAll(
              scheme.primary.withValues(alpha: 0.08),
            ),
          ),
          icon: Icon(Icons.edit, color: fg),
          label: const Text(labelText),
          onPressed: () async {
            // Reset attachment state for this edit session
            editAttachments = EditAttachmentMap();
            // extra step to allow missing attachment field when editing comments
            final initialTempAttachments = (widget.initialAttachments ?? const <Map<String, dynamic>>[])
              .map(TempAttachment.fromMap)
              .toList();
            final payload = await showDialog<NewPostPayload>(
              context: context,
              builder: (_) => NewPostDialog(
                dialogTitle: 'Edit ${widget.type.singular}',
                tempFolder: widget.type.tempFolder,
                postType: widget.type.singular,
                initialTitle: widget.initialTitle,
                initialText: widget.initialText,
                initialAttachments: initialTempAttachments,
                initialCloseEnquiryOnPublish: widget.initialCloseEnquiryOnPublish,
                initialEnquiryConclusion: widget.initialEnquiryConclusion,
              ),
            );
            if (payload == null) return;
            if (!context.mounted) return;

            //compare inital and final attachments to update the editAttachmentsMap
            final payloadAttachMap = payload.attachments.map((a) => a.toMap());
            final payloadAttachList = payloadAttachMap.toList();
            if ((widget.initialAttachments?.isNotEmpty ?? false) ||
                (payloadAttachList.isNotEmpty)) {
              final initialAttachmentNumber = widget.initialAttachments?.length ?? 0;
              final finalAttachmentNumber = payloadAttachList.length;
              final newAttachmentNumber = payloadAttachList
              .where((m) {
                final pathString = (m['storagePath'] ?? '').toString();
                final firstPart = pathString.split('/').first;
                return firstPart.contains('temp');
              })
              .length;
              final removedAttachmentNumber = newAttachmentNumber + initialAttachmentNumber - finalAttachmentNumber;
              if (newAttachmentNumber > 0) {
                editAttachments.add = true;
              }
              if (removedAttachmentNumber > 0) {
                editAttachments.remove = true;
                final initialPaths = (widget.initialAttachments ?? const [])
                  .map((m) => (m['storagePath'] ?? m['path'])?.toString())
                  .whereType<String>()
                  .toList();
                final finalPaths = payload.attachments.map((m) => m.storagePath).toList();

                editAttachments.removeList = initialPaths.toSet().difference(finalPaths.toSet()).toList();
              }
              payload.attachments.removeWhere((a) {
                final pathString = a.storagePath;
                final firstPart = pathString.split('/').first;
                return !firstPart.contains('temp');
              });
            }

            final editPostPayload = PostPayload(
              postType: widget.type,
              title: payload.title,
              postText: payload.text,
              attachments: payload.attachments,
              parentIds: widget.parentIds,
              postId: widget.postId,
              isPublished: widget.isPublished,
              editAttachments: editAttachments,
              closeEnquiryOnPublish: payload.closeEnquiryOnPublish,
              enquiryConclusion: payload.enquiryConclusion,
              );
            
            if (!context.mounted) return;
            await editPost(
              context,
              editPostPayload,
            );
          },
        ),
      ),
    );
  }
}