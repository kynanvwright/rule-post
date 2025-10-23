// flutter_app/lib/api/notification_api.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


final updateEmailNotificationsProvider =
    FutureProvider.family<void, bool>((ref, enabled) async {
  // 🔎 Use the same region you deployed to (e.g., europe-west8)
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
  final callable = functions.httpsCallable('setEmailNotificationsOn');

  try {
    final res = await callable.call(<String, dynamic>{'enabled': enabled});
    debugPrint('setEmailNotificationsOn OK → ${res.data}');

    // Force a token refresh so claims update can be seen client-side
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  } on FirebaseFunctionsException catch (e) {
    // 🔎 This captures backend HttpsError {code,message,details}
    debugPrint('CFN ERROR: code=${e.code} message=${e.message} details=${e.details}');
    rethrow; // let UI show a snackbar, etc.
  } catch (e, st) {
    debugPrint('CFN UNKNOWN ERROR: $e\n$st');
    rethrow;
  }
});