import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ---------- ENQUIRIES LIST (left pane at top level) ----------
class EnquiriesList extends StatelessWidget {
  const EnquiriesList({super.key, this.filter = const {}});
  final Map<String, String> filter;

  Query<Map<String, dynamic>> _buildQuery() {
    var q = FirebaseFirestore.instance
        .collection('enquiries')
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        )
        ;

    // Simple examples: status=open, team=ETNZ
    if (filter['status'] == 'open') {
      q = q.where('isOpen', isEqualTo: true);
    } else if (filter['status'] == 'closed') {
      q = q.where('isOpen', isEqualTo: false);
    }
    // if (filter['published'] == 'true') {
    //   q = q.where('isPublished', isEqualTo: true);
    // }
    // if (filter['team'] != null) {
    //   q = q.where('team', isEqualTo: filter['team']);
    // }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final query = _buildQuery();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Firestore stream error: ${snap.error}');
          return const Center(child: Text('Failed to load enquiries'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No enquiries'));
        }
        return ListView.separated(
          key: const PageStorageKey('EnquiriesList'),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final numLabel = (data['enquiryNumber'] ?? '–').toString();
            final isOpen = data['isOpen'] == true;
            final isPublished = data['isPublished'] == true;

            return ListTile(
              dense: true,
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('E-$numLabel • ${isOpen ? "Open" : "Closed"}'
                  '${isPublished ? "" : " • Draft"}'),
              onTap: () {
                context.go('/enquiries/${d.id}'); // detail in right pane
              },
            );
          },
        );
      },
    );
  }
}

/// ---------- RESPONSES LIST (left pane at responses/comments level) ----------
class ResponsesList extends StatelessWidget {
  const ResponsesList({super.key, required this.enquiryId});
  final String enquiryId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load responses'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No responses yet'));
        }
        return ListView.separated(
          key: PageStorageKey('ResponsesList-$enquiryId'),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data['titleText'] ?? 'Response').toString();
            final author = (data['authorName'] ?? 'Unknown').toString();
            final rNum = (data['responseNumber'] ?? (i + 1)).toString();

            return ListTile(
              dense: true,
              title: Text('Response $rNum: $title',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(author),
              onTap: () {
                context.go('/enquiries/$enquiryId/responses/${d.id}');
              },
            );
          },
        );
      },
    );
  }
}

/// ---------- OPTIONAL: COMMENTS LIST (if you want left pane at comments level) ----------
class CommentsList extends StatelessWidget {
  const CommentsList({
    super.key,
    required this.enquiryId,
    required this.responseId,
  });

  final String enquiryId;
  final String responseId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .collection('comments')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load comments'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No comments yet'));
        }
        return ListView.separated(
          key: PageStorageKey('CommentsList-$responseId'),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final author = (data['authorName'] ?? 'Unknown').toString();
            final preview = (data['text'] ?? '').toString();

            return ListTile(
              dense: true,
              title: Text(author),
              subtitle: Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                context.go(
                  '/enquiries/$enquiryId/responses/$responseId/comments/${d.id}',
                );
              },
            );
          },
        );
      },
    );
  }
}
