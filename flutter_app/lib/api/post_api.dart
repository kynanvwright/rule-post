import '../core/models/attachments.dart';
import '../auth/widgets/auth_check.dart';

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
      'Either enquiryText or attachments must be provided',
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
  final result = await callFunctionSafely<Map<String, dynamic>>(
  name: 'createPost',
  data: payload,
  );
  return result['id'] as String;
}

