// user_detail.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final roleProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  final token = await user?.getIdTokenResult(); // use true if you *just* updated claims
  return token?.claims?['role'] as String?;
});

final teamProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  final token = await user?.getIdTokenResult(); // use true if you *just* updated claims
  return token?.claims?['team'] as String?;
});
