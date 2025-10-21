import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/widgets/doc_view.dart';

final db = FirebaseFirestore.instance;


// Helper: apply status filter + stable sort
List<DocView> filterAndSort(
  List<DocView> items, {
  String statusFilter = '',
  Map<String, String> sortDirections = const {}, // e.g. {'enquiryNumber': 'desc'}
}) {
  var all = items;

  // ── Apply status filter ───────────────────────────
  if (statusFilter == 'open') {
    all = all.where((e) => e.data()['isOpen'] == true).toList();
  } else if (statusFilter == 'closed') {
    all = all.where((e) => e.data()['isOpen'] == false).toList();
  }

  // ── Multi-key stable sort with direction ───────────
  all.sort((a, b) {
    for (final key in sortDirections.keys) {
      final av = a.data()[key];
      final bv = b.data()[key];
      if (av == bv) continue;

      final dir = sortDirections[key] ?? 'asc';
      int cmp = 0;

      if (av is num && bv is num) {
        cmp = av.compareTo(bv);
      } else if (av is Comparable && bv is Comparable) {
        cmp = av.compareTo(bv);
      }

      if (cmp != 0) {
        return dir == 'desc' ? -cmp : cmp;
      }
    }
    return 0;
  });

  return all;
}


List<DocView> Function(List<DocView>) makeFilterSorter({
  String statusFilter = '',
  Map<String, String> sortDirections = const {},
}) {
  return (items) => filterAndSort(
        items,
        statusFilter: statusFilter,
        sortDirections: sortDirections,
      );
}


Stream<List<DocView>> publicEnquiriesStream({
  required String statusFilter,
}) {
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
      .map(makeFilterSorter(statusFilter: statusFilter));

    return public$;
}


Stream<List<DocView>> combinedEnquiriesStream({
  required String statusFilter,
  String? teamId,
}) {

  // 1) Public, published enquiries
  final public$ = publicEnquiriesStream(statusFilter: statusFilter);

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
        for (final d in pub) {byId[d.id] = d;}
        for (final d in mine) {byId[d.id] = d;}
        return filterAndSort(
          byId.values.toList()
          , statusFilter: statusFilter
          , sortDirections: {'enquiryNumber': 'desc'});
      },
    );
  });
}


Stream<List<DocView>> draftEnquiriesStream({
  required String statusFilter,
  String? teamId,
}) {

  // 1) Public, published enquiries

  if (teamId == null) {
      debugPrint('[combinedEnquiriesStream] ⏭ Not logged in — skipping draftDocStreams.');
    return const Stream.empty();
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
      return const Stream.empty();
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
        .map((list) => list.whereType<DocView>().toList())
        .map(makeFilterSorter(
          statusFilter: statusFilter,
          sortDirections: {
            'enquiryNumber': 'desc',
          }));

    // Merge public + drafts, de-dupe by id, then filter/sort once.
    return teamDrafts$;
  });
}

Stream<List<DocView>> combinedResponsesStream({
  // required Map<String, String> filter,
  required String enquiryId,
  String? teamId,
}) {
  final db = FirebaseFirestore.instance;

  // Helper: apply status filter + stable sort
  List<DocView> sortPosts(
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

  // 1) Public, published responses
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
      .map(sortPosts); // pre-filter/sort so we can short-circuit later
  if (teamId == null) {
      debugPrint('[combinedResponsesStream] $enquiryId: ⏭ Not logged in — skipping draftDocStreams.');
    return public$;
  }

  // 2) Team draft IDs
  final draftIds$ = db
      .collection('drafts')
      .doc('posts')
      .collection(teamId)
      .where("postType", isEqualTo: "response")
      .where('parentIds', arrayContains: enquiryId)
      .limit(2)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList())
      .map((ids) { ids.sort(); return ids; })
      .distinct(listEquals);

  // 3) If there are no draft IDs, just return public$.
  //    Otherwise, fetch those draft docs and merge.
  return draftIds$.switchMap((ids) {
    if (ids.isEmpty) {
      debugPrint('[combinedResponsesStream] $enquiryId: no draft -> public only');
      return public$;
    }

    if (ids.length > 1) {
      debugPrint('[combinedResponsesStream] $enquiryId: ❗multiple drafts detected: $ids');
      // choose a policy: first, or prefer latest by updatedAt, etc.
      // For now, take the first (stable due to sort).
    }
    final draftId = ids.first;

    final draftDoc$ = db.collection('enquiries')
      .doc(enquiryId)
      .collection('responses')
      .doc(draftId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      )
      .snapshots()
      .map<DocView?>((ds) => ds.exists ? DocView(ds.id, ds.reference, ds.data()!) : null)
      .onErrorReturn(null)
      .startWith(null); // ensure immediate combine

    return CombineLatestStream.combine2<List<DocView>, DocView?, List<DocView>>(
      public$,
      draftDoc$,
      (pub, draft) {
        if (draft == null) return pub;
        final map = { for (final d in pub) d.id : d };
        map[draft.id] = draft; // upsert/override
        debugPrint('[combinedResponsesStream] $enquiryId: draft found -> combined with published list');
        return sortPosts(map.values.toList());
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
  List<DocView> sortPosts(
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
      .map(sortPosts); // pre-filter/sort so we can short-circuit later
  if (teamId == null) {
      debugPrint('[combinedCommentsStream] $responseId: ⏭ Not logged in — skipping draftDocStreams.');
    return public$;
  }

  // 2) Team draft IDs
  final draftIds$ = db
      .collection('drafts')
      .doc('posts')
      .collection(teamId)
      .where("postType", isEqualTo: "comment")
      .where("parentIds", arrayContains: responseId)
      .limit(5) // guardrails; tune as needed
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList())
      .map((ids) { ids.sort(); return ids; })
      .distinct(listEquals);

  // 3) If there are no draft IDs, just return public$.
  return draftIds$.switchMap((ids) {
    if (ids.isEmpty) {
      debugPrint('[combinedCommentsStream] $responseId: no drafts -> public only');
      return public$;
    }

    // build per-doc streams; initial null to avoid stalling combine
    final draftDocStreams = ids.map((id) {
      final docRef = db.collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .collection('comments')
        .doc(id)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );
      return docRef.snapshots()
        .map<DocView?>((ds) => ds.exists ? DocView(ds.id, ds.reference, ds.data()!) : null)
        .onErrorReturn(null)
        .startWith(null);
    }).toList();

    final teamDrafts$ = CombineLatestStream.list(draftDocStreams)
      .map((list) => list.whereType<DocView>().toList());

    return CombineLatestStream.combine2<List<DocView>, List<DocView>, List<DocView>>(
      public$,
      teamDrafts$,
      (pub, drafts) {
        final byId = { for (final d in pub) d.id : d };
        for (final d in drafts) { byId[d.id] = d; } // upsert
        return sortPosts(byId.values.toList());
      },
    );
  });
}