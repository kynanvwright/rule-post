class Post {
  final String id;
  final String postType;          // 'enquiry' | 'response' | 'comment'
  final String? parentId;         // response→enquiryId, comment→responseId, enquiry→null
  final DateTime createdAt;
  final bool isUnread;            // or derive (e.g. hasUnreadChild)

  Post({
    required this.id,
    required this.postType,
    required this.parentId,
    required this.createdAt,
    this.isUnread = false,
  });
}

/// Iterates in hierarchy order: enquiry → responses → comments
/// with level-specific sorting:
/// - Enquiries: unread first, then newest first
/// - Responses: unread first, then newest first
/// - Comments:  oldest first (typical for discussion flow)
Iterable<MapEntry<String, Post>> iterateERCOrdered(
  Map<String, Post> items, {
  int Function(Post a, Post b)? compareEnquiries,
  int Function(Post a, Post b)? compareResponses,
  int Function(Post a, Post b)? compareComments,
}) sync* {
  if (items.isEmpty) return;

  // Split by level (cheap guards + clarity)
  final enquiries = <String>[];
  final responsesByEnquiry = <String, List<String>>{};
  final commentsByResponse = <String, List<String>>{};

  for (final e in items.entries) {
    final p = e.value;
    switch (p.postType) {
      case 'enquiry':
        enquiries.add(p.id);
        break;
      case 'response':
        if (p.parentId != null) {
          (responsesByEnquiry[p.parentId!] ??= <String>[]).add(p.id);
        }
        break;
      case 'comment':
        if (p.parentId != null) {
          (commentsByResponse[p.parentId!] ??= <String>[]).add(p.id);
        }
        break;
      default:
        // Ignore unknown types
        break;
    }
  }

  // Default comparators per level (override via params if you want)
  int byUnreadDescThenNewest(Post a, Post b) {
    final au = a.isUnread ? 1 : 0, bu = b.isUnread ? 1 : 0;
    if (au != bu) return bu - au;                       // unread first
    return b.createdAt.compareTo(a.createdAt);          // newest first
  }

  int commentsOldestFirst(Post a, Post b) =>
      a.createdAt.compareTo(b.createdAt);

  final cmpEnq = compareEnquiries ?? byUnreadDescThenNewest;
  final cmpResp = compareResponses ?? byUnreadDescThenNewest;
  final cmpComm = compareComments ?? commentsOldestFirst;

  // Sort enquiries (roots)
  enquiries.sort((a, b) => cmpEnq(items[a]!, items[b]!));

  // Yield: enquiry → responses (sorted) → comments (sorted)
  for (final eid in enquiries) {
    final ePost = items[eid]!;
    yield MapEntry(eid, ePost);

    final resp = responsesByEnquiry[eid];
    if (resp == null) continue;

    resp.sort((a, b) => cmpResp(items[a]!, items[b]!));
    for (final rid in resp) {
      final rPost = items[rid]!;
      yield MapEntry(rid, rPost);

      final comm = commentsByResponse[rid];
      if (comm == null) continue;

      comm.sort((a, b) => cmpComm(items[a]!, items[b]!));
      for (final cid in comm) {
        yield MapEntry(cid, items[cid]!);
      }
    }
  }

  // Optional: cover strays (bad parent links). Uncomment if needed.
  // final yielded = HashSet<String>()..addAll(enquiries)
  //   ..addAll(responsesByEnquiry.values.expand((x) => x))
  //   ..addAll(commentsByResponse.values.expand((x) => x));
  // for (final id in items.keys) {
  //   if (!yielded.contains(id)) yield MapEntry(id, items[id]!);
  // }
}
