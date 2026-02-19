// flutter_app/lib/riverpod/user_detail.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits on login, logout, and token refreshes
final firebaseUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.idTokenChanges(),
);

// Reads the current user's custom claims from their ID token
// - claims are a Map ({} when signed out or no claims)
final allClaimsProvider = StreamProvider<Map<String, Object?>>((ref) async* {
  final userStream = FirebaseAuth.instance.idTokenChanges();
  await for (final user in userStream) {
    if (user == null) {
      yield const {};
      continue;
    }
    // Force fresh token so custom claims are up-to-date
    await user.getIdToken(true);
    final token = await user
        .getIdTokenResult(); // no force; stream covers refreshes
    // Ensure a fresh, mutable map
    yield (token.claims ?? const <String, Object?>{});
  }
});

extension ClaimReader on Map<String, Object?> {
  bool getBool(String key, {bool fallback = false}) {
    final v = this[key];
    if (v is bool) return v;
    if (v is String) return (v.toLowerCase() == 'true');
    if (v is num) return v != 0;
    return fallback;
  }

  String? getString(String key) {
    final v = this[key];
    return v is String ? v : null;
  }
}

/// If you *just* updated claims server-side and need an immediate refresh:
Future<void> forceRefreshClaims() async {
  await FirebaseAuth.instance.currentUser?.getIdToken(true);
}

// Various derived user detail providers:

final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(firebaseUserProvider).value;
  return user != null;
});

final roleProvider = Provider<String?>(
  (ref) => ref
      .watch(allClaimsProvider)
      .maybeWhen(data: (c) => c['role'] as String?, orElse: () => null),
);

final teamProvider = Provider<String?>(
  (ref) => ref
      .watch(allClaimsProvider)
      .maybeWhen(data: (c) => c['team'] as String?, orElse: () => null),
);

final isTeamAdminProvider = Provider<bool>((ref) {
  final claims = ref
      .watch(allClaimsProvider)
      .maybeWhen(data: (m) => m, orElse: () => const <String, Object?>{});
  return claims.getBool('teamAdmin', fallback: false) ||
      claims.getString('role') == 'teamAdmin';
});

// True only for the site-level super admin (role=admin)
final isSiteAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(roleProvider);
  return role == 'admin';
});

final emailNotificationsOnProvider = Provider<bool>((ref) {
  final claimsAsync = ref.watch(allClaimsProvider);
  final claims = claimsAsync.asData?.value ?? const <String, Object?>{};
  return (claims['emailNotificationsOn'] as bool?) ?? false;
});

final emailNotificationsScopeProvider = Provider<String>((ref) {
  final claimsAsync = ref.watch(allClaimsProvider);
  final claims = claimsAsync.asData?.value ?? const <String, Object?>{};
  return (claims['emailNotificationsScope'] as String?) ?? 'all';
});
