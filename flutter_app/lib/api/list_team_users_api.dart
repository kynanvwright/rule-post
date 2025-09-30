import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<List<String>> listTeamUsers() async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('listTeamUsers');

    final res = await callable.call();

    // Expecting: ["a@x.com", "b@y.com", ...]
    final data = res.data;

    if (data is List) {
      final emails = data.map((e) => e.toString()).toList();
      debugPrint('✅ Loaded ${emails.length} emails: $emails');
      return emails;
    } else {
      throw StateError(
          'Unexpected response format: expected List<String>, got ${data.runtimeType}');
    }
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ Cloud Function error: ${e.code} – ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('❌ Unexpected error: $e');
    rethrow;
  }
}
