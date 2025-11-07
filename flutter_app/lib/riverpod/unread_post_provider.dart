//riverpod/unread_post_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_detail.dart';


class UnreadDot extends ConsumerWidget {
  const UnreadDot(this.enquiryId, {this.expanded = false, super.key});
  final String enquiryId;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadByIdProvider(enquiryId));

    final showDot = 
      (unreadAsync?['isUnread'] == true) ||
      ((unreadAsync?['hasUnreadChild'] == true) && !expanded);

    return AnimatedOpacity(
      opacity: showDot ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(
          Icons.circle,
          size: 8,
          color: Colors.blueAccent,
        ),
      ),
    );
  }
}



// auth + firestore helpers (nice to centralise)
final uidProvider = Provider<String?>((ref) {
  ref.watch(firebaseUserProvider);
  return FirebaseAuth.instance.currentUser?.uid;
});


final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});


/// Canonical live source: ALL unreadPost docs for this user (both `isUnread` and those with `hasUnreadChild`)
/// If the collection is large, see Variant B below to stream only "needs attention".
final unreadPostsStreamProvider =
    StreamProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();

  final fs = ref.watch(firestoreProvider);
  return fs
      .collection('user_data')
      .doc(uid)
      .collection('unreadPosts')
      .snapshots()
      .map((snap) => { for (final d in snap.docs) d.id: d.data() });
});


/// Derived: count of strictly unread (server-backed but computed client-side to avoid a 2nd listener)
final unreadStrictCountProvider = Provider.autoDispose<int>((ref) {
  // Use `select` so we only rebuild when the map shape/values change, not on intermediate AsyncValue states.
  final asyncMap = ref.watch(unreadPostsStreamProvider);
  return asyncMap.maybeWhen(
    data: (m) => m.values.where((e) => e['isUnread'] == true).length,
    orElse: () => 0,
  );
});


/// Derived: lookup a single doc by id (family). Uses select to avoid rebuilding unrelated items.
final unreadByIdProvider = Provider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
  return ref.watch(
    unreadPostsStreamProvider.select((asyncMap) =>
      asyncMap.maybeWhen(
        data: (m) => m[id],
        orElse: () => null,
      ),
    ),
  );
});
