import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<int?> publishCompetitorResponses(String enquiryId) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('responseInstantPublisher');

    final result = await callable.call(<String, dynamic>{
      'enquiryID': enquiryId.trim(),
      'rcResponse': false,
    });

    final raw = result.data;

    if (raw is Map) {
    final data = result.data;
    if (data['ok'] != true) {
    debugPrint('Function returns map, did not succeed');
    }
    return data['num_published'] ?? 0;
    } else {
      debugPrint('Function does not return map.');
      return null;
    }
  } on FirebaseFunctionsException catch (e) {
    // Backend threw HttpsError
    debugPrint('❌ Cloud Function error: ${e.code} – ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
    rethrow;
  }
}
