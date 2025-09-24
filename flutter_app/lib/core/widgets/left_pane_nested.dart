import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../content/widgets/new_post_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'left_pane_frame.dart';

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
      title: 'Enquiries',
      actions: [
        NewPostButton(type: PostType.enquiry),
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
            final n = (data['enquiryNumber'] ?? 'Unnumbered').toString();

            return ExpansionTile(
              key: PageStorageKey('enq_$id'),
              initiallyExpanded: selected,
              title: _RowTile(
                label: 'RE #$n - $title',
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
        if (!snap.hasData) {
          return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return leafInfo('No responses yet'); // small muted text
        }

        return Column(
          children: docs.map((d) {
            final id = d.id;
            final data = d.data();
            final label = 'Response ${data['roundNumber'] ?? 'x'}.${data['responseNumber'] ?? 'x'}';
            final isOpen = id == initiallyOpenResponseId;

            return Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: ListTile(
                key: PageStorageKey('resp_${enquiryId}_$id'),
                title: _RowTile(
                  label: label,
                  selected: isOpen && initiallySelectedCommentId == null,
                  onTap: () => context.go('/enquiries/$enquiryId/responses/$id'),
                ),
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

Widget leafInfo(String text) => Padding(
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
