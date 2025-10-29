// flutter_app/lib/api/post_api.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/models/attachments.dart';


class PostApi {
  PostApi({this.region = 'europe-west8'})
      : _functions = FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: region
        );

  final String region;
  final FirebaseFunctions _functions;

  /// Calls the CF to create an enquiry. Returns the new doc id.
  Future<String> createPost({
    required String postType,
    required String title,
    String? postText,
    List<TempAttachment>? attachments,
    List<String>? parentIds,
  }) async {
    // Require at least one of enquiryText or attachments
    if ((postText == null || postText.isEmpty) &&
        (attachments == null || attachments.isEmpty)) {
      throw ArgumentError(
        'Either plain post text or attachments must be provided',
      );
    }
    // package data for Cloud Function
    final payload = {
      'postType': postType,
      'title': title,
      if (postText != null) 'postText': postText,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toMap()).toList(),
      if (parentIds != null && parentIds.isNotEmpty) 'parentIds': parentIds,
    };
    // call the function
    final result = await _functions.httpsCallable('createPost').call(payload);
    final data = (result.data as Map).cast<String, dynamic>();
    return data['id'] as String;
  }

    Future<String> editPost({
    required String postType,
    required String title,
    String? postText,
    List<TempAttachment>? attachments,
    List<String>? parentIds,
    required String postId,
    required Map<String, dynamic> editAttachments,
  }) async {
    // Require at least one of enquiryText or attachments
    if ((postText == null || postText.isEmpty) &&
        (attachments == null || attachments.isEmpty) &&
        (editAttachments["remove"] == false)) {
      throw ArgumentError(
        'Either plain post text or attachments must be provided',
      );
    }
    // package data for Cloud Function
    final payload = {
      'postType': postType,
      'title': title,
      'postId': postId,
      'editAttachments': editAttachments,
      if (postText != null) 'postText': postText,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toMap()).toList(),
      if (parentIds != null && parentIds.isNotEmpty) 'parentIds': parentIds,
    };
    // debugPrint('payload runtime types:');
    // debugPrint('postType: ${postType.runtimeType}');
    // debugPrint('title: ${title.runtimeType}');
    // debugPrint('postId: ${postId.runtimeType}');
    debugPrint('editAttachments: $editAttachments');
    // debugPrint('payload full: $payload');
    // call the function
    final result = await _functions.httpsCallable('editPost').call(payload);
    final data = (result.data as Map).cast<String, dynamic>();
    return data['id'] as String;
  }
}