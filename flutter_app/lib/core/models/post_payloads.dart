// lib/core/models/post_payloads.dart
import 'package:flutter/foundation.dart';
import 'package:rule_post/core/models/attachments.dart';
import 'package:rule_post/core/models/post_types.dart';


@immutable
sealed class PostPayload {
  final PostType type;
  final String? title;
  final String? postText; // called postText on the wire
  final List<TempAttachment> attachments;
  final String? postId;
  final bool? isPublished;               // optional toggle
  final EditAttachmentMap? editAttachments;


  const PostPayload({
    required this.type,
    this.title,
    this.postText,
    this.attachments = const [],
    this.postId,
    this.isPublished,
    this.editAttachments = const EditAttachmentMap(),
  });

  /// Common JSON shared by all payloads
  @protected
  Map<String, Object?> baseJson() => {
        'postType': type.singular,
        if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
        if (postText != null && postText!.trim().isNotEmpty) 'postText': postText!.trim(),
        if (attachments.isNotEmpty) 'attachments': attachments.map((a) => a.toMap()).toList(),
        if (postId != null && postId!.trim().isNotEmpty) 'postId': postId!.trim(),
        if (postId != null && postId!.trim().isNotEmpty) 'isPublished': isPublished ?? false,
        if (postId != null && postId!.trim().isNotEmpty) 'editAttachments': (editAttachments ?? const EditAttachmentMap()).toJson(),
      };

  Map<String, Object?> toJson();
}

/// ENQUIRY: needs title and (text OR attachments)
final class EnquiryPayload extends PostPayload {
  factory EnquiryPayload({
    String? title,
    String? postText,
    List<TempAttachment> attachments = const [],
  }) {
    final hasText = postText != null && postText.trim().isNotEmpty;
    if (!hasText && attachments.isEmpty) {
      throw ArgumentError('Enquiry requires text or attachments.');
    }
    if (title == null || title.trim().isEmpty) {
      throw ArgumentError('Title cannot be empty.');
    }
    return EnquiryPayload._(
      title: title,
      postText: postText?.trim(),
      attachments: List.unmodifiable(attachments),
    );
  }

  const EnquiryPayload._({
    required super.title,
    super.postText,
    super.attachments = const [],
  }) : super(type: PostType.enquiry);

  @override
  Map<String, Object?> toJson() => baseJson();
}

/// RESPONSE: must target an enquiryId, and have (text OR attachments)
final class ResponsePayload extends PostPayload {
  final String enquiryId;

  factory ResponsePayload({
    required String enquiryId,
    String? title,
    String? postText,
    List<TempAttachment> attachments = const [],
  }) {
    if (enquiryId.trim().isEmpty) {
      throw ArgumentError('enquiryId is required for a response.');
    }
    final hasText = postText != null && postText.trim().isNotEmpty;
    if (!hasText && attachments.isEmpty) {
      throw ArgumentError('Response requires text or attachments.');
    }
    return ResponsePayload._(
      enquiryId: enquiryId.trim(),
      title: title?.trim(),
      postText: postText?.trim(),
      attachments: List.unmodifiable(attachments),
    );
  }

  const ResponsePayload._({
    required this.enquiryId,
    required super.title,
    super.postText,
    super.attachments = const [],
  }) : super(type: PostType.response);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'parentIds': [enquiryId], // your backend can also accept a single id if you prefer
      };
}

/// COMMENT: must target an enquiryId + responseId; usually requires text
final class CommentPayload extends PostPayload {
  final String enquiryId;
  final String responseId;

  factory CommentPayload({
    required String enquiryId,
    required String responseId,
    required String postText, // comments typically require text
    String? title,
    List<TempAttachment> attachments = const [],
  }) {
    if (enquiryId.trim().isEmpty || responseId.trim().isEmpty) {
      throw ArgumentError('enquiryId and responseId are required for a comment.');
    }
    if (postText.trim().isEmpty) {
      throw ArgumentError('Comment text cannot be empty.');
    }
    return CommentPayload._(
      enquiryId: enquiryId.trim(),
      responseId: responseId.trim(),
      title: title?.trim(),
      postText: postText.trim(),
      attachments: List.unmodifiable(attachments),
    );
  }

  const CommentPayload._({
    required this.enquiryId,
    required this.responseId,
    required super.title,
    required super.postText,
    super.attachments = const [],
  }) : super(type: PostType.comment);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'parentIds': [enquiryId, responseId],
      };
}


// Mirrors: type EditAttachmentMap = { add: boolean; remove: boolean; removeList: string[]; }
class EditAttachmentMap {
  final bool add;                 // if true, include attachments to add
  final bool remove;              // if true, process removeList
  final List<String> removeList;  // server ids to remove

  const EditAttachmentMap({
    this.add = false,
    this.remove = false,
    this.removeList = const [],
  });

  Map<String, Object?> toJson() => {
    'add': add,
    'remove': remove,
    if (remove) 'removeList': removeList,
  };
}


Type choosePayloadType(PostType type) => switch (type) {
  PostType.enquiry => EnquiryPayload,
  PostType.response => ResponsePayload,
  PostType.comment => CommentPayload,
};