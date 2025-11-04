//riverpod/unread_post_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_detail.dart';


/// Depends on firebaseUserProvider so it re-evaluates when auth changes.
/// Returns a function you can call to fetch a {docId: true} map,
/// or null if there is no logged-in user.
final unReadEnquiryProvider =
    Provider<Future<Map<String, bool>> Function(String collectionPath)?>((
  ref,
) {
  // Rebuild on auth changes
  ref.watch(firebaseUserProvider);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final firestore = FirebaseFirestore.instance;

  return (String collectionPath) async {
    final snap = await firestore.collection(collectionPath).get();
    return {for (final d in snap.docs) d.id: true};
  };
});


final getDocIdMapProvider =
    Provider<Future<Map<String, bool>> Function(String collectionPath)?>((
  ref,
) {
  // Rebuild on auth changes
  ref.watch(firebaseUserProvider);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final firestore = FirebaseFirestore.instance;

  return (String collectionPath) async {
    final snap = await firestore.collection(collectionPath).get();
    return {for (final d in snap.docs) d.id: true};
  };
});


final getUserScopedIdMapProvider =
    Provider<Future<Map<String, bool>> Function(String userSubcollectionPath)?>((
  ref,
) {
  ref.watch(firebaseUserProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final firestore = FirebaseFirestore.instance;

  // userSubcollectionPath like 'threadReads' or 'unreadPosts'
  return (String userSubcollectionPath) async {
    final p = 'users/$uid/$userSubcollectionPath';
    final snap = await firestore.collection(p).get();
    return {for (final d in snap.docs) d.id: true};
  };
});

// force posttype as input and slice differently, or have separate function

final isUnreadEnquiryStreamProvider =
    StreamProvider.family<bool, String>((ref, enquiryId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream<bool>.empty();

  final docRef = FirebaseFirestore.instance
      .collection('enquiries')
      .doc(enquiryId)
      .collection('read_receipts')
      .doc(uid);

  // unread = !exists
  return docRef.snapshots().map((snap) => !snap.exists);
});


// 2) In your list tile, only the dot watches the boolean via `select`
class UnreadDot extends ConsumerWidget {
  const UnreadDot(this.enquiryId, this.expanded, {super.key});
  final String enquiryId;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadByIdProvider(enquiryId));
    final showDot = 
      (unreadAsync?['isUnread'] == true) 
      || 
      ((unreadAsync?['hasUnreadChild'] == true) && !expanded);
    return showDot
        ? Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Colors.blueAccent, // change to theme colour
            ),
          )
        : const SizedBox.shrink();
  }
}


final unreadPostsProvider = FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  // Re-run when user logs in/out
  ref.watch(firebaseUserProvider);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const {};

  final fs = FirebaseFirestore.instance;
  final snap = await fs
      .collection('user_data')
      .doc(uid)
      .collection('unreadPosts')
      .get();

  return {
    for (final d in snap.docs) d.id: d.data(),
  };
});


final unreadCountsProvider = Provider<Map<String, int>>((ref) {
  final unreadAsync = ref.watch(unreadPostsProvider);

  // Default counts
  var counts = {'enquiry': 0, 'response': 0, 'comment': 0};

  return unreadAsync.whenData((docs) {
    for (final data in docs.values) {
      debugPrint(data['postType']);
      final type = data['postType'];
      if (counts.containsKey(type)) counts[type] = counts[type]! + 1;
    }
    return counts;
  }).value ?? counts;
});

final unreadByIdProvider =
    Provider.family<Map<String, dynamic>?, String>((ref, id) {
  final unread = ref.watch(unreadPostsProvider).valueOrNull;
  return unread?[id];
});
