// flutter_app/lib/riverpod/doc_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// Watch a single enquiry document
final enquiryDocProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, id) {
  final refDoc = FirebaseFirestore.instance
      .collection('enquiries')
      .doc(id)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      );
  return refDoc.snapshots().map((s) => s.data());
});


/// Watch a single response document:
/// path: enquiries/{enquiryId}/responses/{responseId}
final responseDocProvider = StreamProvider.family<
    Map<String, dynamic>?, ({String enquiryId, String responseId})>((ref, ids) {
  final doc = FirebaseFirestore.instance
      .collection('enquiries')
      .doc(ids.enquiryId)
      .collection('responses')
      .doc(ids.responseId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      );

  return doc.snapshots().map((s) => s.data());
});