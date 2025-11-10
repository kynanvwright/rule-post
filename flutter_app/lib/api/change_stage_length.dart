// flutter_app/lib/api/change_stage_length.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

// frontend function which calls the backend changeStageLength function
//  takes the document id of the enquiry and the new stage length (in days) as args
Future<bool> changeStageLength(String enquiryId, int newStageLength) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('changeStageLength');

    // Call the backend function using the input arguments
    final result = await callable.call<Map<String, dynamic>>({
      'enquiryId': enquiryId.trim(),
      'newStageLength' : newStageLength,
    });
    // extract the function output and return function success boolean
    final data = result.data;
    return data['ok'] ?? false;

  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Cloud Function error: ${e.code} – ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
    rethrow;
  }
}