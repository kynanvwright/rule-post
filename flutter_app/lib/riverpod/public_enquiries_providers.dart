import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/doc_view.dart';

final publicEnquiriesProvider = StreamProvider<List<DocView>>((ref) {
  final db = FirebaseFirestore.instance;

  return db
      .collection('enquiries')
      .where('isPublished', isEqualTo: true)
      .orderBy('enquiryNumber', descending: true)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      )
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => DocView(d.id, d.reference, d.data())).toList());
});
