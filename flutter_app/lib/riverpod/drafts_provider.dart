import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final db = FirebaseFirestore.instance;

/// Generic: does current team have any drafts of a given type?
final hasDraftsOfTypeProvider =
    StreamProvider.family<bool, ({String? teamId, String postType})>((ref, key) {
  if (key.teamId == null) {
    return Stream<bool>.value(false);
  } else {
    final q = db
        .collection('drafts')
        .doc('posts')
        .collection(key.teamId ?? '')
        .where('postType', isEqualTo: key.postType)
        .limit(1);

    return q.snapshots().map((s) => s.docs.isNotEmpty).distinct();
    }
});