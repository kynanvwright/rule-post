// flutter_app/lib/api/mark_post_unread.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';


Future<void> markPostUnread(String enquiryId, String? responseId, String? commentId,) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('markPostUnread');

    await callable.call<Map<String, dynamic>>({
      'enquiryId' : enquiryId.trim(),
      'responseId': responseId?.trim(),
      'commentId' : commentId?.trim(),
    });

    return;
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Cloud Function error: ${e.code} – ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
    rethrow;
  }
}