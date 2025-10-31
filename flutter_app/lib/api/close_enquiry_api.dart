// flutter_app/lib/api/close_enquiry_api.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:rule_post/content/widgets/rules_committee_panel.dart';


Future<String?> closeEnquiry(String enquiryId, EnquiryConclusion enquiryConclusion) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('closeEnquiry');
    debugPrint("enquiry conclusion: ${enquiryConclusion.name}");

    // Match the backend key exactly: enquiryID (capital D)
    final result = await callable.call<Map<String, dynamic>>({
      'enquiryID': enquiryId.trim(),
      'enquiryConclusion': enquiryConclusion.name,
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