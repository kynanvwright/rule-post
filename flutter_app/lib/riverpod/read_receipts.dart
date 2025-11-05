// riverpod/read_receipts.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_detail.dart';
import 'unread_post_provider.dart';


/// Emits whenever the Firebase user changes (login / logout / token refresh).
final readReceiptProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(firebaseUserProvider);

  final uid = FirebaseAuth.instance.currentUser?.uid;

  final result = <String, dynamic>{
    'counts': [0, 0, 0], // [enquiries, responses, comments]
  };

  if (uid == null) {
    return result;
  }

  final firestore = FirebaseFirestore.instance;

  final unreadCounts = [0, 0, 0];

  // 1. All published enquiries
  final enquirySnap = await firestore
      .collection('enquiries')
      .where("isPublished", isEqualTo: true)
      .get();

  for (final enquiryDoc in enquirySnap.docs) {
    final enquiryId = enquiryDoc.id;

    // --- ENQUIRY LEVEL ---
    {
      // read_receipts is a subcollection under this enquiry:
      // enquiries/{enquiryId}/read_receipts/{uid}
      final receiptDoc = await firestore
          .collection('enquiries')
          .doc(enquiryId)
          .collection('read_receipts')
          .doc(uid)
          .get();

      final hasUserRead = receiptDoc.exists
          ? (receiptDoc.data()?['read'] == true)
          : false;

      if (!hasUserRead) {
        unreadCounts[0] += 1;
      }
    }

    // 2. Responses under this enquiry
    final responseSnap = await firestore
        .collection('enquiries')
        .doc(enquiryId)
        .collection("responses")
        .where("isPublished", isEqualTo: true)
        .get();

    for (final responseDoc in responseSnap.docs) {
      final responseId = responseDoc.id;

      // --- RESPONSE LEVEL ---
      {
        final receiptDoc = await firestore
            .collection('enquiries')
            .doc(enquiryId)
            .collection("responses")
            .doc(responseId)
            .collection("read_receipts")
            .doc(uid)
            .get();

        final hasUserRead = receiptDoc.exists
            ? (receiptDoc.data()?['read'] == true)
            : false;

        if (!hasUserRead) {
          unreadCounts[1] += 1;
        }
      }

      // 3. Comments under this response
      final commentSnap = await firestore
          .collection('enquiries')
          .doc(enquiryId)
          .collection("responses")
          .doc(responseId)
          .collection("comments")
          .where("isPublished", isEqualTo: true)
          .get();

      for (final commentDoc in commentSnap.docs) {
        final commentId = commentDoc.id;

        // --- COMMENT LEVEL ---
        final receiptDoc = await firestore
            .collection('enquiries')
            .doc(enquiryId)
            .collection("responses")
            .doc(responseId)
            .collection("comments")
            .doc(commentId)
            .collection("read_receipts")
            .doc(uid)
            .get();

        final hasUserRead = receiptDoc.exists
            ? (receiptDoc.data()?['read'] == true)
            : false;

        if (!hasUserRead) {
          unreadCounts[2] += 1;
        }
      }
    }
  }

  result['counts'] = unreadCounts;
  return result;
});


final readReceiptProviderAlt = FutureProvider<List<int>>((ref) async {
  // ref.keepAlive();
  ref.watch(firebaseUserProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [0, 0, 0];

  final fs = FirebaseFirestore.instance;
  final base = fs.collection('user_data').doc(uid).collection('unreadPosts');

  final results = await Future.wait([
    base.where('postType', isEqualTo: "enquiry").count().get(),
    base.where('postType', isEqualTo: "response").count().get(),
    base.where('postType', isEqualTo: "comment").count().get(),
  ]);

  return results.map((r) => r.count ?? 0).toList();
});


final markEnquiryReadProvider =
    Provider<Future<void> Function(String enquiryId)?>((ref) {
      
  ref.watch(firebaseUserProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return null;
  }
  final firestore = FirebaseFirestore.instance;

  return (String enquiryId) async {
    await firestore
        .collection('enquiries')
        .doc(enquiryId)
        .collection('read_receipts')
        .doc(uid)
        .set(
      { 'read': true },
      SetOptions(merge: true),
    );
    await firestore
        .collection('user_data')
        .doc(uid)
        .collection('unreadPosts')
        .doc(enquiryId)
        .delete();
    ref.invalidate(unreadPostsProvider);
  };
});


final markResponsesAndCommentsReadProvider =
    Provider<Future<void> Function(String enquiryId, String responseId)?>((ref) {
  ref.watch(firebaseUserProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final fs = FirebaseFirestore.instance;
  final col = fs.collection('user_data').doc(uid).collection('unreadPosts');

  return (String enquiryId, String responseId) async {
    // 1) Batch delete: response + all its comment children
    final batch = fs.batch();

    // Always delete the response entry itself (if present)
    batch.delete(col.doc(responseId));

    // Paginate comment children (orderBy required for startAfterDocument)
    Query<Map<String, dynamic>> q = col
        .where('postType', isEqualTo: 'comment')
        .where('parentId', isEqualTo: responseId)
        .limit(50);

    while (true) {
      final snap = await q.get();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      if (snap.docs.length < 500) break;
      q = q.startAfterDocument(snap.docs.last);
    }

    await batch.commit();

    // 2) Parent clean-up via server aggregation counts
    // If no unread descendants remain under this enquiry AND the enquiry doc
    // only exists as "hasUnreadChild" (i.e. not "isUnread"), delete it.
    final c1 = await col
        .where('isUnread', isEqualTo: true)
        .where('parentId', isEqualTo: enquiryId)
        .count()
        .get();
    final c2 = await col
        .where('isUnread', isEqualTo: true)
        .where('grandparentId', isEqualTo: enquiryId)
        .count()
        .get();
    final unreadDescendants = (c1.count ?? 0) + (c2.count ?? 0);

    if (unreadDescendants == 0) {
      final enquiryDoc = await col.doc(enquiryId).get();
      final e = enquiryDoc.data();
      // Only remove if it’s merely a “hasUnreadChild” marker
      if (enquiryDoc.exists && (e?['isUnread'] != true)) {
        await enquiryDoc.reference.delete();
      }
    }

    ref.invalidate(unreadPostsProvider);
  };
});
