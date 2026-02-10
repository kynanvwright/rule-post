// flutter_app/lib/api/post_apis.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/models/post_payloads.dart' show PostPayload;
import 'package:rule_post/core/models/post_types.dart' show PostType;
import 'package:rule_post/core/models/types.dart' show Json;

final api = ApiTemplate();


// Used to create a new post
Future<void> createPost(
    BuildContext context,
    PostPayload payload,
) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'createPost', 
    data: payload.toJson(),
    successTitle: 'Post created',
    successMessage: 'Your post is saved and scheduled for publication.',
    failureTitle: 'Couldn’t create post',
    failureMessage: 'Please check details and try again.',
    steps: const [
      'Checking user authentication…',
      'Populating additional post data…',
      'Saving post to database…',
    ],
  );
}


// Used to create a new post
Future<void> editPost(
    BuildContext context,
    PostPayload payload,
) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'editPost', 
    data: payload.toJson(),
    successTitle: 'Post edited',
    successMessage: 'Your post is edited, saved and scheduled for publication.',
    failureTitle: 'Couldn’t create post',
    failureMessage: 'Please check details and try again.',
    steps: const [
      'Checking user authentication…',
      'Populating additional post data…',
      'Saving post to database…',
    ],
  );
}

// Used to delete an unpublished post
Future<void> deletePost(
    BuildContext context, {
    required PostType type,
    required String postId,
    List<String>? parentIds,
}) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'deletePost', 
    data: {
      'postType': type.singular,
      'postId': postId,
      'parentIds': parentIds ?? [],
    },
    successTitle: 'Post deleted',
    successMessage: 'Your post has been permanently deleted.',
    failureTitle: 'Couldn’t delete post',
    failureMessage: 'Please check details and try again.',
    steps: const [
      'Checking user authentication…',
      'Verifying permissions…',
      'Deleting post…',
    ],
  );
}