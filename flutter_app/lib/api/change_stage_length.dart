// flutter_app/lib/api/change_stage_length.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';


Future<bool> changeStageLength(String enquiryId, int newStageLength) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('changeStageLength');

    // Match the backend key exactly: enquiryID (capital D)
    final result = await callable.call<Map<String, dynamic>>({
      'enquiryID': enquiryId.trim(),
      'newStageLength' : newStageLength,
    });

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


// helper to return current stageLength
Future<int> getStageLength(String enquiryId) async {
  final doc = await FirebaseFirestore.instance.collection('enquiries').doc(enquiryId).get();
  if (doc.exists) {
    return doc.data()?['stageLength'];  // returns null if field missing
  } else {
    throw Exception('Document not found');
  }
}