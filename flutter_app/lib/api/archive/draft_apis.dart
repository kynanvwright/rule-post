// flutter_app/lib/api/draft_apis.dart
import 'package:cloud_functions/cloud_functions.dart';

import 'package:rule_post/debug/debug.dart';

Future<List<String>> findDrafts(String postType, List<String> parentIds) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('findDrafts');

    final result = await callable.call({
      'postType': postType,
      'parentIds': parentIds,
    });

    // Expecting the function to return a list of strings.
    final List<dynamic> data = result.data;
    final drafts = data.map((e) => e.toString()).toList();

    d('✅ Found drafts: $drafts');
    return drafts;
  } on FirebaseFunctionsException catch (e) {
    d('❌ Cloud Function error: ${e.code} – ${e.message}');
    return [];
  } catch (e) {
    d('❌ Unexpected error: $e');
    return [];
  }
}


Future<bool> hasDrafts() async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('hasDrafts');

    final result = await callable.call();
    final bool foundDrafts = result.data as bool;

    d('✅ Drafts searched and match result is: $foundDrafts');
    return foundDrafts;
  } on FirebaseFunctionsException catch (e) {
    d('❌ Cloud Function error: ${e.code} – ${e.message}');
    return false;
  } catch (e) {
    d('❌ Unexpected error: $e');
    return false;
  }
}

// import 'api_template.dart';
// import '../../core/widgets/types.dart';

// final api = ApiTemplate();


// Future<Json?> findDrafts(String postType, List<String> parentIds) async {
//   return api.call<Json>('findDrafts', {
//       'postType': postType,
//       'parentIds': parentIds,
//   });
// }


// Future<Json?> hasDrafts() async {
//   return api.call<Json>('hasDrafts', {
//   });
// }