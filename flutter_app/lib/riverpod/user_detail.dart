// user_detail.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 1) Auth stream: emits on login, logout, and token refreshes
final firebaseUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.idTokenChanges(),
);

/// 2) Claims stream: re-compute when the user (or their token) changes
class Claims {
  final String? role;
  final String? team;
  const Claims({this.role, this.team});
}

final claimsProvider = StreamProvider<Claims>((ref) async* {
  final userStream = FirebaseAuth.instance.idTokenChanges();
  await for (final user in userStream) {
    if (user == null) {
      yield const Claims();
      continue;
    }
    final token = await user.getIdTokenResult(); // no force; stream handles refreshes
    final c = token.claims ?? {};
    yield Claims(role: c['role'] as String?, team: c['team'] as String?);
  }
});