// riverpod/read_receipts.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_detail.dart';


/// Emits on login, logout, and token refreshes
final readReceiptProvider = Provider<bool>((ref) {
  // final uid = FirebaseAuth.instance.currentUser?.uid;
  // psuedo-code:
  //  check if post has a document in it's read receipt collection
  return true;
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
    }
  };
});
