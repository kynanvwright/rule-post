// flutter_app/lib/api/create_user_api.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';


Future<void> createUserFromFrontend(String email) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('createUserWithProfile');

    final result = await callable.call({
      'email': email,
    });

    debugPrint('✅ User created: ${result.data}');
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Cloud Function error: ${e.code} – ${e.message}');
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
  }
}