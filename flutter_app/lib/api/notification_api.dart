import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trigger backend to update claim, then force-refresh the ID token
final updateEmailNotificationsProvider =
    FutureProvider.family<void, bool>((ref, enabled) async {
  final callable =
      FirebaseFunctions.instance.httpsCallable('setEmailNotificationsOn');
  await callable.call(<String, dynamic>{'enabled': enabled});
  await FirebaseAuth.instance.currentUser?.getIdToken(true); // refresh claims
});