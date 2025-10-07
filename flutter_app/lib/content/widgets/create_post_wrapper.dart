import 'package:flutter/material.dart';

import '../../api/post_api.dart';
import '../../core/models/attachments.dart';
import 'progress_dialog.dart';

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
    await showProgressFlow<String>(
      context: context,
      steps: const [
        'Checking user authentication…',
        'Populating additional post data…',
        'Saving post to database…',
      ],
      successTitle: 'Post created',
      successMessage: 'Your post is saved and scheduled for publication.',
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
      // SnackBar(content: Text('Created post: $newId')),
      SnackBar(content: Text('Created $postType')),
    );
  } catch (e) {
    // Failure already shown in the dialog; optionally log or map errors:
    debugPrint('Create post failed: $e');
  }
}
