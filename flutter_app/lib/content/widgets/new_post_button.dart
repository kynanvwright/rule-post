import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/post_api.dart';

class NewEnquiryButton extends StatelessWidget {
  const NewEnquiryButton({super.key, required this.currentCategory});

  final String currentCategory;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: const Icon(Icons.add),
      label: const Text('New enquiry'),
      onPressed: () async {
        final payload = await showDialog<_NewEnquiryPayload>(
          context: context,
          builder: (_) => const _NewEnquiryDialog(),
        );
        if (payload == null) return;

        final messenger = ScaffoldMessenger.of(context);
        final api = PostApi();

        try {
          final id = await api.createEnquiry(
            titleText: payload.title,
            enquiryText: payload.text,
          );
          // final id = await api.testPing();
          messenger.showSnackBar(
            const SnackBar(content: Text('Enquiry created')),
          );
          if (context.mounted) {
            // Open it in the right pane, keep current filter.
            context.go('/enquiries/$id?cat=$currentCategory');
          }
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed to create enquiry: $e')),
          );
        }
      },
    );
  }
}

class _NewEnquiryDialog extends StatefulWidget {
  const _NewEnquiryDialog();

  @override
  State<_NewEnquiryDialog> createState() => _NewEnquiryDialogState();
}

class _NewEnquiryDialogState extends State<_NewEnquiryDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New enquiry'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _text,
              decoration: const InputDecoration(labelText: 'Content'),
              minLines: 3,
              maxLines: 6,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!(_form.currentState?.validate() ?? false)) return;
                  setState(() => _busy = true);
                  // Return payload to caller; CF call happens outside dialog.
                  Navigator.pop(
                    context,
                    _NewEnquiryPayload(
                      title: _title.text.trim(),
                      text: _text.text.trim(),
                    ),
                  );
                },
          child: _busy ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }
}

class _NewEnquiryPayload {
  _NewEnquiryPayload({required this.title, required this.text});
  final String title;
  final String text;
}
