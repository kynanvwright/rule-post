import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DocView {
  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> _data;
  DocView(this.id, this.reference, this._data);
  Map<String, dynamic> data() => _data;
}

Stream<List<DocView>> combinedEnquiriesStream({
  required Map<String, String> filter,
  String? teamId,
}) {
  final db = FirebaseFirestore.instance;

  // Helper: apply status filter + stable sort
  List<DocView> _filterAndSort(List<DocView> items) {
    var all = items;
    final status = filter['status'];
    if (status == 'open') {
      all = all.where((e) => e.data()['isOpen'] == true).toList();
    } else if (status == 'closed') {
      all = all.where((e) => e.data()['isOpen'] == false).toList();
    }
    all.sort((a, b) {
      final an = (a.data()['enquiryNumber'] ?? 0) as num;
      final bn = (b.data()['enquiryNumber'] ?? 0) as num;
      return bn.compareTo(an);
    });
    return all;
  }

  // 1) Public, published enquiries
  final public$ = db
      .collection('enquiries')
      .where('isPublished', isEqualTo: true)
      .orderBy('enquiryNumber', descending: true)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      )
      .snapshots()
      .map((snap) => snap.docs.map((d) => DocView(d.id, d.reference, d.data())).toList())
      .map(_filterAndSort); // pre-filter/sort so we can short-circuit later
  if (teamId == null) {
      debugPrint('[combinedEnquiriesStream] ⏭ Not logged in — skipping draftDocStreams.');
    return public$;
  }

  // 2) Team draft IDs
  final draftIds$ = db
      .collection('drafts')
      .doc('posts')
      .collection(teamId)
      .where("postType", isEqualTo: "enquiry")
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList());

  // 3) If there are no draft IDs, just return public$.
  //    Otherwise, fetch those draft docs and merge.
  return draftIds$.switchMap((ids) {
    debugPrint('[combinedEnquiriesStream] draftIds = $ids');
    
    if (ids.isEmpty) {
      // Short-circuit: no per-doc listeners, no combineLatest—cheap!
      debugPrint('[combinedEnquiriesStream] ⏭ No drafts found — skipping draftDocStreams.');
      return public$;
    }

    // Stream the user’s draft enquiry docs
    debugPrint('[combinedEnquiriesStream] 🟢 Found ${ids.length} draft(s) — building streams.');
    final draftDocStreams = ids.map((id) {
      final docRef = db
          .collection('enquiries')
          .doc(id)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (v, _) => v,
          );

      return docRef
          .snapshots()
          // if readable: map to DocView (or null when deleted)
          .map<DocView?>((ds) => ds.exists ? DocView(ds.id, ds.reference, ds.data()!) : null)
          // if NOT readable (permission-denied), just emit null instead of error
          .onErrorReturn(null)
          // ensure CombineLatest has an initial value for this stream
          .startWith(null);
    }).toList();

    final teamDrafts$ = CombineLatestStream.list(draftDocStreams)
        .map((list) => list.whereType<DocView>().toList());

    // Merge public + drafts, de-dupe by id, then filter/sort once.
    return CombineLatestStream.combine2<List<DocView>, List<DocView>, List<DocView>>(
      public$,
      teamDrafts$,
      (pub, mine) {
        final byId = <String, DocView>{};
        for (final d in pub) byId[d.id] = d;
        for (final d in mine) byId[d.id] = d;
        return _filterAndSort(byId.values.toList());
      },
    );
  });
}

Stream<List<DocView>> combinedResponsesStream({
  // required Map<String, String> filter,
  required String enquiryId,
  String? teamId,
}) {
  final db = FirebaseFirestore.instance;

  // Helper: apply status filter + stable sort
  List<DocView> _sortPosts(
    List<DocView> items, {
    bool ascendingRound = true,
    bool ascendingResponse = true,
  }) {
    final all = [...items]; // copy to avoid mutating input
    all.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aRound = (aData['roundNumber'] ?? 99) as num;
      final bRound = (bData['roundNumber'] ?? 99) as num;
      final aResponse = (aData['responseNumber'] ?? 99) as num;
      final bResponse = (bData['responseNumber'] ?? 99) as num;

      // 1️⃣ Primary: roundNumber
      final roundCompare = ascendingRound
          ? aRound.compareTo(bRound)
          : bRound.compareTo(aRound);
      if (roundCompare != 0) return roundCompare;

      // 2️⃣ Secondary: responseNumber
      return ascendingResponse
          ? aResponse.compareTo(bResponse)
          : bResponse.compareTo(aResponse);
    });
    return all;
  }

  // 1) Public, published enquiries
  final public$ = db
      .collection('enquiries')
      .doc(enquiryId)
      .collection('responses')
      .where('isPublished', isEqualTo: true)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      )
      .snapshots()
      .map((snap) => snap.docs.map((d) => DocView(d.id, d.reference, d.data())).toList())
      .map(_sortPosts); // pre-filter/sort so we can short-circuit later
  if (teamId == null) {
      debugPrint('[combinedResponsesStream] ⏭ Not logged in — skipping draftDocStreams.');
    return public$;
  }

  // 2) Team draft IDs
  final draftIds$ = db
      .collection('drafts')
      .doc('posts')
      .collection(teamId)
      .where("postType", isEqualTo: "response")
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList());

  // 3) If there are no draft IDs, just return public$.
  //    Otherwise, fetch those draft docs and merge.
  return draftIds$.switchMap((ids) {
    debugPrint('[combinedResponsesStream] draftIds = $ids');
    
    if (ids.isEmpty) {
      // Short-circuit: no per-doc listeners, no combineLatest—cheap!
      debugPrint('[combinedResponsesStream] ⏭ No drafts found — skipping draftDocStreams.');
      return public$;
    }

    // Stream the user’s draft enquiry docs
    debugPrint('[combinedResponsesStream] 🟢 Found ${ids.length} draft(s) — building streams.');
    final draftDocStreams = ids.map((id) {
      final docRef = db
          .collection('enquiries')
          .doc(enquiryId)
          .collection('responses')
          .doc(id)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (v, _) => v,
          );

      return docRef
          .snapshots()
          // if readable: map to DocView (or null when deleted)
          .map<DocView?>((ds) => ds.exists ? DocView(ds.id, ds.reference, ds.data()!) : null)
          // if NOT readable (permission-denied), just emit null instead of error
          .onErrorReturn(null)
          // ensure CombineLatest has an initial value for this stream
          .startWith(null);
    }).toList();

    final teamDrafts$ = CombineLatestStream.list(draftDocStreams)
        .map((list) => list.whereType<DocView>().toList());

    // Merge public + drafts, de-dupe by id, then filter/sort once.
    return CombineLatestStream.combine2<List<DocView>, List<DocView>, List<DocView>>(
      public$,
      teamDrafts$,
      (pub, mine) {
        final byId = <String, DocView>{};
        for (final d in pub) byId[d.id] = d;
        for (final d in mine) byId[d.id] = d;
        return _sortPosts(byId.values.toList());
      },
    );
  });
}

Stream<List<DocView>> combinedCommentsStream({
  // required Map<String, String> filter,
  required String enquiryId,
  required String responseId,
  String? teamId,
}) {
  final db = FirebaseFirestore.instance;

  // Helper: apply status filter + stable sort
  List<DocView> _sortPosts(
    List<DocView> items, {
    bool ascending = true,
  }) {
    final all = [...items]; // copy to avoid mutating input
    all.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aComment = (aData['commentNumber'] ?? 99) as num;
      final bComment = (bData['commentNumber'] ?? 99) as num;

      // 1️⃣ Primary: roundNumber
      final compare = ascending
          ? aComment.compareTo(bComment)
          : bComment.compareTo(aComment);

      return compare;
    });
    return all;
  }

  // 1) Public, published enquiries
  final public$ = db
      .collection('enquiries')
      .doc(enquiryId)
      .collection('responses')
      .doc(responseId)
      .collection('comments')
      .where('isPublished', isEqualTo: true)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      )
      .snapshots()
      .map((snap) => snap.docs.map((d) => DocView(d.id, d.reference, d.data())).toList())
      .map(_sortPosts); // pre-filter/sort so we can short-circuit later
  if (teamId == null) {
      debugPrint('[combinedCommentsStream] ⏭ Not logged in — skipping draftDocStreams.');
    return public$;
  }

  // 2) Team draft IDs
  final draftIds$ = db
      .collection('drafts')
      .doc('posts')
      .collection(teamId)
      .where("postType", isEqualTo: "comment")
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList());

  // 3) If there are no draft IDs, just return public$.
  //    Otherwise, fetch those draft docs and merge.
  return draftIds$.switchMap((ids) {
    debugPrint('[combinedCommentsStream] draftIds = $ids');
    
    if (ids.isEmpty) {
      // Short-circuit: no per-doc listeners, no combineLatest—cheap!
      debugPrint('[combinedCommentsStream] ⏭ No drafts found — skipping draftDocStreams.');
      return public$;
    }

    // Stream the user’s draft enquiry docs
    debugPrint('[combinedCommentsStream] 🟢 Found ${ids.length} draft(s) — building streams.');
    final draftDocStreams = ids.map((id) {
      final docRef = db
          .collection('enquiries')
          .doc(enquiryId)
          .collection('responses')
          .doc(responseId)
          .collection('comments')
          .doc(id)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (s, _) => s.data() ?? {},
            toFirestore: (v, _) => v,
          );

      return docRef
          .snapshots()
          // if readable: map to DocView (or null when deleted)
          .map<DocView?>((ds) => ds.exists ? DocView(ds.id, ds.reference, ds.data()!) : null)
          // if NOT readable (permission-denied), just emit null instead of error
          .onErrorReturn(null)
          // ensure CombineLatest has an initial value for this stream
          .startWith(null);
    }).toList();

    final teamDrafts$ = CombineLatestStream.list(draftDocStreams)
        .map((list) => list.whereType<DocView>().toList());

    // Merge public + drafts, de-dupe by id, then filter/sort once.
    return CombineLatestStream.combine2<List<DocView>, List<DocView>, List<DocView>>(
      public$,
      teamDrafts$,
      (pub, mine) {
        final byId = <String, DocView>{};
        for (final d in pub) byId[d.id] = d;
        for (final d in mine) byId[d.id] = d;
        return _sortPosts(byId.values.toList());
      },
    );
  });
}
