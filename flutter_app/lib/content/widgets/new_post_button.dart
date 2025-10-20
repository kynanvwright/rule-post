import 'dart:async';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'create_post_wrapper.dart';
import 'custom_progress_indicator.dart';
import '../../core/models/attachments.dart' show TempAttachment;

enum PostType { enquiry, response, comment }

extension on PostType {
  String get apiName => switch (this) {
        PostType.enquiry => 'enquiry',
        PostType.response => 'response',
        PostType.comment => 'comment',
      };
  String get labelSingular => switch (this) {
        PostType.enquiry => 'enquiry',
        PostType.response => 'response',
        PostType.comment => 'comment',
      };
  String get tempFolder => switch (this) {
        PostType.enquiry => 'enquiries_temp',
        PostType.response => 'responses_temp',
        PostType.comment => 'comments_temp',
      };
}

/// Use this one button for all three types.
class NewPostButton extends StatefulWidget {
  const NewPostButton({
    super.key,
    required this.type,
    this.parentIds,
    this.isLocked = false,
    this.lockedReason,
  });

  final PostType type;
  final List<String>? parentIds;
  final bool isLocked;
  final String? lockedReason;

  @override
  State<NewPostButton> createState() => _NewPostButtonState();
}

class _NewPostButtonState extends State<NewPostButton> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final locked = widget.isLocked;
    const labelText = 'New';

    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;

    // Dimmed look when locked (keeps theme hue, lowers alpha only).
    final bgColor = locked ? bg.withValues(alpha: 0.55) : bg;
    final fgColor = locked ? fg.withValues(alpha: 0.55) : fg;

    return Semantics(
      button: true,
      enabled: !locked, // SRs know it's unavailable, but we keep it focusable.
      label: locked && widget.lockedReason != null
          ? 'New (locked — ${widget.lockedReason})'
          : 'New',
      child: Tooltip(
        key: _tooltipKey,
        triggerMode: TooltipTriggerMode.longPress, // hover still works on desktop
        message: locked
            ? (widget.lockedReason ?? 'This action is currently locked.')
            : 'Create a new ${widget.type.labelSingular}',
        child: FilledButton.icon(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(bgColor),
            foregroundColor: WidgetStatePropertyAll(fgColor),
            overlayColor: WidgetStatePropertyAll(
              locked
                  ? scheme.onSurface.withValues(alpha: 0.04)
                  : scheme.primary.withValues(alpha: 0.08),
            ),
          ),
          icon: Icon(locked ? Icons.lock_outline : Icons.add, color: fgColor),
          label: const Text(labelText),
          onPressed: () async {
            if (locked) {
              final s = _tooltipKey.currentState;
              if (s is TooltipState) s.ensureTooltipVisible();
              return;
            }

            final payload = await showDialog<_NewPostPayload>(
              context: context,
              builder: (_) => _NewPostDialog(
                dialogTitle: 'New ${widget.type.labelSingular}',
                tempFolder: widget.type.tempFolder,
                postType: widget.type.labelSingular,
              ),
            );
            if (payload == null) return;
            if (!context.mounted) return;

            await onCreatePostPressed(
              context,
              postType: widget.type.apiName,
              title: payload.title,
              postText: payload.text,
              attachments: (payload.attachments == null || payload.attachments!.isEmpty)
                  ? null
                  : payload.attachments,
              parentIds: widget.parentIds,
            );
          },
        ),
      ),
    );
  }
}



class _NewPostDialog extends StatefulWidget {
  const _NewPostDialog({
    required this.dialogTitle,
    required this.tempFolder,
    required this.postType,
  });

  final String dialogTitle;
  final String tempFolder;
  final String postType;


  @override
  State<_NewPostDialog> createState() => _NewPostDialogState();
}

class _NewPostDialogState extends State<_NewPostDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _text = TextEditingController();
  final List<TempAttachment> _pending = [];
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_busy && !_uploading;

    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: Form(
        key: _form,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.postType != 'comment') ...[
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(labelText: widget.postType == 'enquiry' ? 'Title' : 'Summary (optional)'),
                    validator: (v) =>
                        ((widget.postType == 'enquiry') && (v == null || v.trim().isEmpty)) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                  TextFormField(
                    controller: _text,
                    decoration: InputDecoration(
                      labelText: widget.postType == 'comment' ? 'Comment' : 'Details',
                      suffixIcon: widget.postType == 'comment' 
                      ? null 
                      : Tooltip(
                        message: 'Plain text alternative to attaching a file',
                        child: Icon(Icons.info_outline, size: 18),
                        ),
                    ),
                    maxLines: 5,
                    validator: (v) =>
                        ((widget.postType == 'comment') && (v == null || v.trim().isEmpty)) ? 'Content is required' : null,
                  ),
                  const SizedBox(height: 16),
                if (widget.postType != 'comment') ...[
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _addAttachmentToTemp,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Add attachment'),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Note: large attachments may take a minute or two to upload',
                        child: Icon(
                          Icons.info_outline, 
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_uploading) ...[
                    RotatingProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                ],
                if (_pending.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pending
                          .map((a) => InputChip(
                                label: Text(a.name),
                                onDeleted: () =>
                                    setState(() => _pending.remove(a)),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit
              ? () async {
                  if (!(_form.currentState?.validate() ?? false)) return;
                  if (widget.postType == 'enquiry' && _text.text.trim().isEmpty && _pending.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No details or attachments provided.')));
                    return;
                  }
                  if (widget.postType == 'response' && _title.text.trim().isEmpty && _text.text.trim().isEmpty && _pending.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No input provided.')));
                    return;
                  }
                  setState(() => _busy = true);
                  if (context.mounted) {
                    Navigator.pop(
                      context,
                      _NewPostPayload(
                        title: _title.text.trim(),
                        text: _text.text.trim(),
                        attachments: _pending.toList(),
                      ),
                    );
                  }
                }
              : null,
          child: _busy ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _addAttachmentToTemp() async {
    if (_uploading) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _toast('You must be signed in to add attachments.');
      return;
    }

    try {
      // Don’t await anything before opening the picker
      List<web.File>? webFiles;

      if (kIsWeb) {
        webFiles = await _pickWebFiles(
          accept: '.pdf,.doc,.docx',
          multiple: true,
        );
      } else {
        // Non-web fallback keeps your old plugin flow
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          withData: true,
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx'],
        );
        if (picked == null || picked.files.isEmpty) return;

        // If you ever target mobile/desktop again, this will be used.
        setState(() => _uploading = true);
        int success = 0;
        final errors = <String>[];
        for (final f in picked.files) {
          try {
            await _uploadOneFile(uid, f);
            success++;
          } catch (e) {
            errors.add('${f.name}: $e');
          }
        }
        if (success > 0) _toast('Uploaded $success file${success == 1 ? '' : 's'}.');
        if (errors.isNotEmpty) _toast('Some files failed:\n${errors.join('\n')}');
        return;
      }

      // User canceled or no files selected
      if (webFiles == null || webFiles.isEmpty) return;

      // Now it’s safe to set uploading + do any warm-ups concurrently
      setState(() => _uploading = true);
      // Fire and forget App Check warm-up (don’t break user gesture earlier)
      unawaited(FirebaseAppCheck.instance.getToken(true));

      // Bounded concurrency
      const maxConcurrent = 3;
      int success = 0;
      final errors = <String>[];

      for (var i = 0; i < webFiles.length; i += maxConcurrent) {
        final batch = webFiles.sublist(
          i,
          (i + maxConcurrent > webFiles.length) ? webFiles.length : i + maxConcurrent,
        );
        await Future.wait(batch.map((f) async {
          try {
            await _uploadOneWebBlob(uid, f);
            success++;
          } catch (e) {
            errors.add('${f.name}: $e');
          }
        }));
      }

      if (success > 0) _toast('Uploaded $success file${success == 1 ? '' : 's'}.');
      if (errors.isNotEmpty) _toast('Some files failed:\n${errors.join('\n')}');
    } catch (e) {
      _toast('Attachment failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }


  Future<List<web.File>?> _pickWebFiles({
    String accept = '',
    bool multiple = true,
  }) async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = accept
      ..multiple = multiple
      ..style.display = 'none'; // keep it invisible

    // Must be in DOM for some browsers
    web.document.body?.append(input);

    // Synchronously trigger the dialog — no awaits before this
    input.click();

    // Wait for user selection
    await input.onChange.first;

    final list = <web.File>[];
    final files = input.files;
    if (files != null) {
      final len = files.length;
      for (var i = 0; i < len; i++) {
        final f = files.item(i);
        if (f != null) list.add(f);
      }
    }

    input.remove();
    return list.isEmpty ? null : list;
  }


  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _sanitiseName(String name) =>
      name.replaceAll(RegExp(r'[^\w.\-+]'), '_').substring(0, name.length.clamp(0, 200));

  String? _guessContentType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      default:
        return null;
    }
  }

  Future<void> _uploadOneFile(String uid, PlatformFile f) async {
    final bytes = f.bytes; // present on web (withData: true)
    final path = f.path;   // present on mobile/desktop
    if (bytes == null && (path == null || path.isEmpty)) {
      throw 'Could not read file bytes or path.';
    }

    final name = f.name;
    final size = f.size;
    final ext = (f.extension ?? '').toLowerCase();
    final contentType = _guessContentType(ext) ?? 'application/octet-stream';

    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = _sanitiseName(name);
    final tempPath = '${widget.tempFolder}/$uid/$ts-$safeName';

    final ref = FirebaseStorage.instance.ref(tempPath);

    if (kIsWeb || bytes != null) {
      await ref.putData(bytes!, SettableMetadata(contentType: contentType));
    } else {
      await ref.putFile(File(path!), SettableMetadata(contentType: contentType));
    }

    _pending.add(TempAttachment(
      name: name,
      storagePath: tempPath,
      size: size,
      contentType: contentType,
    ));
  }

  Future<void> _uploadOneWebBlob(String uid, web.File f) async {
    final name = f.name;
    final size = f.size;
    final browserType = f.type.isNotEmpty ? f.type : null;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final contentType =
        browserType ?? _guessContentType(ext) ?? 'application/octet-stream';

    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = _sanitiseName(name);
    final tempPath = '${widget.tempFolder}/$uid/$ts-$safeName';

    final ref = FirebaseStorage.instance.ref(tempPath);
    await ref.putBlob(f, SettableMetadata(contentType: contentType));

    _pending.add(TempAttachment(
      name: name,
      storagePath: tempPath,
      size: size,
      contentType: contentType,
    ));
  }
}


class _NewPostPayload {
  _NewPostPayload({
    required this.title,
    required this.text,
    this.attachments,
  });

  final String title;
  final String text;
  final List<TempAttachment>? attachments;
}