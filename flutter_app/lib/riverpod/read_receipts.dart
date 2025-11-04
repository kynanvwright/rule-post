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
    Provider<Future<void> Function(
      String enquiryId,
      String responseId,
    )?>((ref) {
      
  ref.watch(firebaseUserProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) { return null; }
  final firestore = FirebaseFirestore.instance;

  return (
    String enquiryId,
    String responseId,
  ) async {
    // mechanism 1, per-post
    await firestore
      .collection('enquiries')
      .doc(enquiryId)
      .collection('responses')
      .doc(responseId)
      .collection('read_receipts')
      .doc(uid)
      .set(
        { 'read': true },
        SetOptions(merge: true),
      );
    // mechanism 2, per-user
    await firestore
        .collection('user_data')
        .doc(uid)
        .collection('unreadPosts')
        .doc(responseId)
        .delete();
        // needs a follow-up to check if the parent should have its state changed
        // roughly: 
        //    are there no docs where parentId/grandparentId matches this enquiry?
        //    is the parent enquiry only "hasUnreadChild", not "isUnread"
        //    if both, delete parent entry

    // find all child comments and run this on them
    final querySnapshot = await firestore
      .collection('enquiries')
      .doc(enquiryId)
      .collection('responses')
      .doc(responseId)
      .collection('comments')
      .where('isPublished', isEqualTo: true)
      .get();
    // loop through the comment documents
    for (final commentDoc in querySnapshot.docs) {
      await firestore
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .collection('comments')
        .doc(commentDoc.id)
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
          .doc(commentDoc.id)
          .delete();
        // needs a follow-up to check if the parent/grandparent should have its state changed
    }
    ref.invalidate(unreadPostsProvider);
  };
});
