// user_detail.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final token = await user.getIdTokenResult(); // no force; stream covers refreshes
    // Ensure a fresh, mutable map
    yield Map<String, Object?>.from(token.claims ?? const {});
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

/// If you *just* updated claims server-side and need an immediate refresh:
Future<void> forceRefreshClaims() async {
  await FirebaseAuth.instance.currentUser?.getIdToken(true);
}
/// Derive a typed bool (default false if missing/invalid)
final emailNotificationsOnProvider = Provider<bool>((ref) {
  final claimsAsync = ref.watch(allClaimsProvider);
  return claimsAsync.maybeWhen(
    data: (c) {
      final v = c['emailNotificationsOn'];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v != 0;
      return false;
    },
    orElse: () => false,
  );
});
