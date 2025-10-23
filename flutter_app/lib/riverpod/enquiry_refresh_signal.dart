import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// final enquiriesRefreshSignal  = StateProvider<int>((_) => 0);

final draftIdsProvider =
    StreamProvider.family<List<String>, String?>((ref, teamId) {
  if (teamId == null) return const Stream<List<String>>.empty();
  final db = FirebaseFirestore.instance;
  return db
      .collection('drafts').doc('posts').collection(teamId)
      .where('postType', isEqualTo: 'enquiry')
      .snapshots()
      .map((s) => (s.docs.map((d) => d.id).toList()..sort()))
      .distinct(listEquals);
});