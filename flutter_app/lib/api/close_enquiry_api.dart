// flutter_app/lib/api/close_enquiry_api.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';


Future<String?> closeEnquiry(String enquiryId) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('closeEnquiry');

    // Match the backend key exactly: enquiryID (capital D)
    final result = await callable.call<Map<String, dynamic>>({
      'enquiryID': enquiryId.trim(),
    });

    final data = result.data;
    if (data['ok'] == true) {
      // Match backend return field name
      return data['enquiryID'] as String;
    }
    return null;
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Cloud Function error: ${e.code} – ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
    rethrow;
  }
}