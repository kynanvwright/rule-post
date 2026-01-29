import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:rule_post/riverpod/post_streams.dart';


// Watches draft enquiries for your team, refreshes left pane when drafts change
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


// Watches draft responses for your team, to lock/unlock response creation
final hasResponseDraftProvider =
    StreamProvider.family<bool, ({String enquiryId, String teamId})>((ref, key) {
  return responseDraftIdsStream(enquiryId: key.enquiryId, teamId: key.teamId)
      .map((ids) => ids.isNotEmpty)
      .distinct();
});
