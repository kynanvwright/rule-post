import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../content/widgets/new_post_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'left_pane_switcher.dart';

class LeftPaneNested extends StatefulWidget {
  const LeftPaneNested({super.key, required this.state});
  final GoRouterState state;

  @override
  State<LeftPaneNested> createState() => _LeftPaneNestedState();
}

class _LeftPaneNestedState extends State<LeftPaneNested> {
  String? get _enquiryId => widget.state.pathParameters['enquiryId'];
  String? get _responseId => widget.state.pathParameters['responseId'];
  String? get _commentId => widget.state.pathParameters['commentId'];

  @override
  Widget build(BuildContext context) {
    final qp = widget.state.uri.queryParameters; // keep your filters
    return LeftPaneFrame(
      title: 'Files',
      actions: [
        if (_enquiryId == null) NewPostButton(type: PostType.enquiry),
        if (_enquiryId != null && _responseId == null) NewPostButton(type: PostType.response, parentIds: [_enquiryId!]),
        if (_responseId != null) NewPostButton(type: PostType.comment, parentIds: [_enquiryId!, _responseId!]),
      ],
      child: _EnquiriesTree(
        initiallyOpenEnquiryId: _enquiryId,
        initiallyOpenResponseId: _responseId,
        initiallySelectedCommentId: _commentId,
        filter: qp,
      ),
    );
  }
}

class _EnquiriesTree extends StatelessWidget {
  const _EnquiriesTree({
    required this.initiallyOpenEnquiryId,
    required this.initiallyOpenResponseId,
    required this.initiallySelectedCommentId,
    required this.filter,
  });

  final String? initiallyOpenEnquiryId;
  final String? initiallyOpenResponseId;
  final String? initiallySelectedCommentId;
  final Map<String, String> filter;

  @override
  Widget build(BuildContext context) {
    final listQuery = buildEnquiriesQuery(filter); // your existing builder
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listQuery.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Failed to load enquiries'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No enquiries yet'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final id = d.id;
            final data = d.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final selected = id == initiallyOpenEnquiryId;

            return ExpansionTile(
              key: PageStorageKey('enq_$id'),
              initiallyExpanded: selected,
              title: _RowTile(
                label: title,
                selected: selected && initiallyOpenResponseId == null,
                onTap: () => context.go('/enquiries/$id'),
              ),
              children: [
                _ResponsesBranch(
                  enquiryId: id,
                  initiallyOpenResponseId: initiallyOpenResponseId,
                  initiallySelectedCommentId: initiallySelectedCommentId,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ResponsesBranch extends StatelessWidget {
  const _ResponsesBranch({
    required this.enquiryId,
    required this.initiallyOpenResponseId,
    required this.initiallySelectedCommentId,
  });

  final String enquiryId;
  final String? initiallyOpenResponseId;
  final String? initiallySelectedCommentId;

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('enquiries').doc(enquiryId)
        .collection('responses')
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: false); // tweak as needed

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {debugPrint('Firestore stream error: ${snap.error}');}
        if (!snap.hasData) return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _LeafInfo('No responses'); // small muted text
        }

        return Column(
          children: docs.map((d) {
            final id = d.id;
            final data = d.data();
            final label = (data['title'] ?? 'Response').toString();
            final isOpen = id == initiallyOpenResponseId;

            return Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: ExpansionTile(
                key: PageStorageKey('resp_${enquiryId}_$id'),
                initiallyExpanded: isOpen,
                title: _RowTile(
                  label: label,
                  selected: isOpen && initiallySelectedCommentId == null,
                  onTap: () => context.go('/enquiries/$enquiryId/responses/$id'),
                ),
                children: [
                  _CommentsBranch(
                    enquiryId: enquiryId,
                    responseId: id,
                    initiallySelectedCommentId: initiallySelectedCommentId,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CommentsBranch extends StatelessWidget {
  const _CommentsBranch({
    required this.enquiryId,
    required this.responseId,
    required this.initiallySelectedCommentId,
  });

  final String enquiryId;
  final String responseId;
  final String? initiallySelectedCommentId;

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('enquiries').doc(enquiryId)
        .collection('responses').doc(responseId)
        .collection('comments')
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(
          padding: EdgeInsets.only(left: 24, bottom: 8), child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Padding(
          padding: EdgeInsets.only(left: 24, bottom: 8), child: Text('No comments', style: TextStyle(color: Colors.black54)));

        return Column(
          children: docs.map((d) {
            final id = d.id;
            final data = d.data();
            final label = (data['text'] ?? 'Comment').toString();
            final selected = id == initiallySelectedCommentId;
            return Padding(
              padding: const EdgeInsets.only(left: 24.0),
              child: _RowTile(
                label: label,
                selected: selected,
                onTap: () => context.go('/enquiries/$enquiryId/responses/$responseId/comments/$id'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
      selected: selected,
    );
  }
}

Widget _LeafInfo(String text) => Padding(
  padding: const EdgeInsets.only(left: 24, bottom: 8),
  child: Text(text, style: const TextStyle(color: Colors.black54)),
);

Query<Map<String, dynamic>> buildEnquiriesQuery(Map<String, String> filter) {
  var q = FirebaseFirestore.instance
      .collection('enquiries')
      .where('isPublished', isEqualTo: true)
      .orderBy('publishedAt', descending: true)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      );

  // Filters (same as your EnquiriesList)
  if (filter['status'] == 'open') {
    q = q.where('isOpen', isEqualTo: true);
  } else if (filter['status'] == 'closed') {
    q = q.where('isOpen', isEqualTo: false);
  }
  // if (filter['team'] != null) q = q.where('team', isEqualTo: filter['team']);

  return q;
}

Widget _asyncList<T>(
  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap, {
  required Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>) onData,
  required Widget empty,
  required String contextLabel,
}) {
  if (snap.hasError) {
    final err = snap.error!;
    debugPrint('Firestore error [$contextLabel]: $err');
    if (err is FirebaseException) {
      debugPrint('  code: ${err.code}');
      debugPrint('  message: ${err.message}');
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text('Failed to load $contextLabel.\n$err',
          style: const TextStyle(color: Colors.redAccent)),
    );
  }

  // Show a spinner only while we're still waiting AND we have no data yet.
  if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: CircularProgressIndicator(),
    );
  }

  final docs = snap.data?.docs ?? const [];
  if (docs.isEmpty) return empty;

  return onData(docs);
}