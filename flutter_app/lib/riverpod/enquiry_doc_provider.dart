import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
