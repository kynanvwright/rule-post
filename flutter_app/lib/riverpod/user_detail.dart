// riverpod/user_detail.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Emits on login, logout, and token refreshes
final firebaseUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.idTokenChanges(),
);

/// All claims as a Map<String, Object?> ({} when signed out or no claims)
final allClaimsProvider = StreamProvider<Map<String, Object?>>((ref) async* {
  final userStream = FirebaseAuth.instance.idTokenChanges();
  await for (final user in userStream) {
    if (user == null) {
      yield const {};
      continue;
    }
    // Force fresh token so custom claims are up-to-date
    await user.getIdToken(true);
    final token = await user.getIdTokenResult(); // no force; stream covers refreshes
    // Ensure a fresh, mutable map
    yield (token.claims ?? const <String, Object?>{});
  }
});

/// Handy typed helpers built on top of the map (optional)
final roleProvider = Provider<String?>(
  (ref) => ref.watch(allClaimsProvider).maybeWhen(
        data: (c) => c['role'] as String?,
        orElse: () => null,
      ),
);

final teamProvider = Provider<String?>(
  (ref) => ref.watch(allClaimsProvider).maybeWhen(
        data: (c) => c['team'] as String?,
        orElse: () => null,
      ),
);

final teamAdminProvider = Provider<bool?>(
  (ref) => ref.watch(allClaimsProvider).maybeWhen(
        data: (c) => c['teamAdmin'] as bool?,
        orElse: () => null,
      ),
);

/// If you *just* updated claims server-side and need an immediate refresh:
Future<void> forceRefreshClaims() async {
  await FirebaseAuth.instance.currentUser?.getIdToken(true);
}

// 2) Derived flag with sensible default
final emailNotificationsOnProvider = Provider<bool>((ref) {
  final claimsAsync = ref.watch(allClaimsProvider);
  final claims = claimsAsync.asData?.value ?? const <String, Object?>{};
  return (claims['emailNotificationsOn'] as bool?) ?? false;
});

// 3) Imperative action as a function-returning Provider
final setEmailNotifications = Provider<Future<void> Function(bool)>((ref) {
  return (bool enabled) async {
    debugPrint('[setEmailNotifications] start enabled=$enabled');

    // IMPORTANT: use your deployed region here
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
    final callable = functions.httpsCallable('setEmailNotificationsOn');

    await callable.call(<String, dynamic>{'enabled': enabled});

    // Refresh the ID token so new claims can be seen
    final auth = FirebaseAuth.instance;
    await auth.currentUser?.getIdToken(true);

    // Option A: quick invalidate so UI re-reads claims
    ref.invalidate(allClaimsProvider);

    // Option B (optional): short poll to ensure claim flips before returning
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    var delay = const Duration(milliseconds: 120);
    while (DateTime.now().isBefore(deadline)) {
      await auth.currentUser?.getIdToken(true);
      final res = await auth.currentUser?.getIdTokenResult(true);
      final got = (res?.claims?['emailNotificationsOn'] as bool?) ?? false;
      if (got == enabled) {
        debugPrint('[setEmailNotifications] claim observed enabled=$enabled');
        return;
      }
      await Future.delayed(delay);
      delay *= 2;
    }
    // No big deal: claims often catch up a moment later.
    debugPrint('[setEmailNotifications] claim not observed yet; continuing');
  };
});
