import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<String?> deleteUserByEmail(String email) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('deleteUser');

    final result = await callable.call(<String, dynamic>{
      'email': email,
    });

    final data = result.data as Map<String, dynamic>;
    if (data['ok'] == true) {
      return data['deletedUid'] as String;
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
