import 'package:flutter/material.dart';
import '../../api/post_api.dart';
import '../../core/models/attachments.dart' show TempAttachment;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
class NewPostButton extends StatelessWidget {
  const NewPostButton({
    super.key,
    required this.type,
    this.parentIds, // e.g. [enquiryId] for response, [enquiryId, responseId] for comment
  });

  final PostType type;
  final List<String>? parentIds;

  @override
  Widget build(BuildContext context) {
    // final titleText = 'New ${type.labelSingular}';
    final titleText = 'New';
    return FilledButton.icon(
      icon: const Icon(Icons.add),
      label: Text(titleText),
      onPressed: () async {
        final payload = await showDialog<_NewPostPayload>(
          context: context,
          builder: (_) => _NewPostDialog(
            dialogTitle: titleText,
            tempFolder: type.tempFolder,
            postType: type.labelSingular,
          ),
        );
        if (payload == null) return;

        final messenger = ScaffoldMessenger.of(context);
        final api = PostApi();

        try {
          await api.createPost(
            postType: type.apiName,
            title: payload.title,
            postText: payload.text,
            attachments: (payload.attachments == null ||
                    payload.attachments!.isEmpty)
                ? null
                : payload.attachments,
            parentIds: parentIds, // server side will validate/use this
          );
          messenger.showSnackBar(
            SnackBar(content: Text('${_cap(titleText)} ${type.labelSingular} created')),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to create ${type.labelSingular}: $e')),
          );
        }
      },
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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
                    decoration: InputDecoration(labelText: widget.postType == 'comment' ? 'Comment' : 'Details'),
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
                      const SizedBox(width: 12),
                      if (_uploading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
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
    try {
      setState(() => _uploading = true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _toast('You must be signed in to add attachments.');
        setState(() => _uploading = false);
        return;
      }

      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _uploading = false);
        return;
      }

      final f = picked.files.single;
      final bytes = f.bytes;
      if (bytes == null) {
        _toast('Could not read file bytes.');
        setState(() => _uploading = false);
        return;
      }

      final name = f.name;
      final size = f.size;
      final ext = (f.extension ?? '').toLowerCase();
      final contentType = _guessContentType(ext) ?? 'application/octet-stream';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = _sanitiseName(name);
      final tempPath = '${widget.tempFolder}/$uid/$ts-$safeName';

      final ref = FirebaseStorage.instance.ref(tempPath);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));

      _pending.add(TempAttachment(
        name: name,
        storagePath: tempPath,
        size: size,
        contentType: contentType,
      ));

      setState(() => _uploading = false);
    } catch (e) {
      setState(() => _uploading = false);
      _toast('Attachment failed: $e');
    }
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
