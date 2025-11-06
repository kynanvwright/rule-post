// riverpod/read_receipts.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_detail.dart';


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
        .collection('user_data')
        .doc(uid)
        .collection('unreadPosts')
        .doc(enquiryId)
        .delete();
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
  };
});
