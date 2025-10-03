import 'package:flutter/material.dart';
import '../../api/post_api.dart'; // where your PostApi lives
import 'progress_dialog.dart'; // where you put showProgressFlow
import '../../core/models/attachments.dart';

final _postApi = PostApi(region: 'europe-west8');

Future<void> onCreatePostPressed(
  BuildContext context, {
  required String postType,
  required String title,
  String? postText,
  List<TempAttachment>? attachments,
  List<String>? parentIds,
}) async {
  try {
    final newId = await showProgressFlow<String>(
      context: context,
      steps: const [
        'Checking user authentication…',
        'Populating additional post data…',
        'Saving post to database…',
      ],
      successTitle: 'Post created',
      successMessage: 'Your post is now live.',
      failureTitle: 'Couldn’t create post',
      failureMessage: 'Please check details and try again.',
      autoCloseOnSuccess: true,
      autoCloseAfter: Duration(seconds: 3),
      barrierDismissibleWhileRunning: false,
      action: () async {
        // If you have an auth/app-check refresher, call it here:
        // await ensureFreshAuth();

        return await _postApi.createPost(
          postType: postType,
          title: title,
          postText: postText,
          attachments: attachments,
          parentIds: parentIds,
        );
      },
    );

    // Optional follow-up (post dialog)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created post: $newId')),
    );
  } catch (e) {
    // Failure already shown in the dialog; optionally log or map errors:
    debugPrint('Create post failed: $e');
  }
}
