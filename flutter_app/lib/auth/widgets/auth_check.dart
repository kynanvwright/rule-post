// flutter_app/lib/auth/widgets/auth_check.dart
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:rule_post/debug/debug.dart';

/// Ensures we're logged in and tokens are fresh before a backend call.
/// Throws a FirebaseAuthException with code 'user-not-logged-in' if no user.
Future<void> ensureFreshAuth({Duration waitForUser = const Duration(seconds: 3)}) async {
  final auth = FirebaseAuth.instance;

  // 1) Wait briefly for Firebase to rehydrate user (common on web after reload)
  var user = auth.currentUser;
  if (user == null) {
    try {
      user = await auth.authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(waitForUser);
    } on TimeoutException {
      // Still null after waiting
    }
  }
  if (user == null) {
    throw FirebaseAuthException(
      code: 'user-not-logged-in',
      message: 'No Firebase user is currently signed in.',
    );
  }

  // 2) Refresh user profile and ID token (force refresh fixes many 401s)
  await user.reload(); // refreshes profile/claims
  await user.getIdToken(true); // true = force refresh

  // 3) If App Check is enabled server-side (enforceAppCheck: true), refresh it too
  // Safe to call even if App Check isn't enabled; remove if you don't use App Check.
  try {
    await FirebaseAppCheck.instance.getToken(true); // true = force refresh
    // d("App Check token: $token");
  } catch (e) {
    // Swallow if App Check not configured on this platform.
    d("App Check fail.");
  }
  d("App Check successful.");
}


/// Call a callable Cloud Function after making sure auth/app-check are fresh.
Future<T> callFunctionSafely<T>({
  required String name,
  Map<String, dynamic>? data,
  String region = 'europe-west8',
}) async {
  await ensureFreshAuth();

  final functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: region
    );
  final callable = functions.httpsCallable(name);

  try {
    final result = await callable.call<Map<String, dynamic>?>(data);
    // Cast smartly to T; adjust as needed for your return shape
    return (result.data as T);
  } on FirebaseFunctionsException catch (e) {
    // Common case: auth/app-check rejection due to drift — try one more hard refresh then retry once.
    if (e.code == 'unauthenticated' || e.code == 'failed-precondition') {
      await ensureFreshAuth();
      final retry = await callable.call<Map<String, dynamic>?>(data);
      return (retry.data as T);
    }
    rethrow;
  }
}