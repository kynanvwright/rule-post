import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<int?> publishCompetitorResponses(String enquiryId) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('teamResponseInstantPublisher');

    final result = await callable.call(<String, dynamic>{
      'enquiryID': enquiryId.trim(),
    });

    final data = result.data as Map<String, dynamic>;
    if (data['ok']) {
      return data['num_published'] ?? 0;
    } else {
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
