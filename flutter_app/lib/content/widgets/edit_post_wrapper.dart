// flutter_app/lib/content/widgets/edit_post_wrapper.dart
import 'package:flutter/material.dart';

import '../../api/post_api.dart';
import '../../auth/widgets/auth_check.dart';
import '../../core/models/attachments.dart';
import 'progress_dialog.dart';


final _postApi = PostApi(region: 'europe-west8');

Future<void> onEditPostPressed(
  BuildContext context,  {
  required String postType,
  required String title,
  String? postText,
  List<TempAttachment>? attachments,
  List<String>? parentIds,
  required String postId,
}) async {
  try {
    await showProgressFlow<String>(
      context: context,
      steps: const [
        'Checking user authentication…',
        'Populating additional post data…',
        'Saving post to database…',
      ],
      successTitle: 'Post edited',
      successMessage: 'Your post is edited, saved and scheduled for publication.',
      failureTitle: 'Couldn’t create post',
      failureMessage: 'Please check details and try again.',
      autoCloseOnSuccess: true,
      autoCloseAfter: Duration(seconds: 3),
      barrierDismissibleWhileRunning: false,
      action: () async {
        // auth/app-check refresher
        await ensureFreshAuth();

        return await _postApi.editPost(
          postType: postType,
          title: title,
          postText: postText,
          attachments: attachments,
          parentIds: parentIds,
          postId: postId,
        );
      },
    );

    // Optional follow-up (post dialog)
    if (!context.mounted) return;

  } catch (e) {
    // Failure already shown in the dialog; optionally log or map errors:
    debugPrint('Edit post failed: $e');
  }
}