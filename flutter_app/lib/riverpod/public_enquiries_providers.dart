import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _DocView {
  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> _data;
  _DocView(this.id, this.reference, this._data);
  Map<String, dynamic> data() => _data;
}

final publicEnquiriesProvider = StreamProvider<List<_DocView>>((ref) {
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
          snap.docs.map((d) => _DocView(d.id, d.reference, d.data())).toList());
});
