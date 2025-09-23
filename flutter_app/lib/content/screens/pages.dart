import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/new_post_button.dart';
import '../widgets/fancy_attachment_tile.dart';

/// -------------------- NO SELECTION --------------------
class NoSelectionPage extends StatelessWidget {
  const NoSelectionPage({super.key, this.message = 'Select an item to view details.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// -------------------- ENQUIRY DETAIL --------------------
class EnquiryDetailPage extends StatelessWidget {
  const EnquiryDetailPage({super.key, required this.enquiryId});
  final String enquiryId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Failed to load enquiry'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() ?? {};

        final title = (data['title'] ?? 'Untitled').toString();
        final enquiryNumber = (data['enquiryNumber'] ?? '—').toString();
        final postText = (data['postText'] ?? '').toString().trim();
        final attachments = (data['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        // Optional status flags. Only show if present.
        final isOpen = data['isOpen'] == true;
        final teamsCanRespond = data['teamsCanRespond'] == true;
        final teamsCanComment = data['teamsCanComment'] == true;

        return _DetailScaffold(
          // HEADER (within a card)
          headerLines: [
            'Rule Enquiry #$enquiryNumber – $title',
          ],
          subHeaderLines: const [], // enquiries themselves don’t need a subheader
          // META (chips row under header)
          meta: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const SizedBox(height: 16),
              if (data.containsKey('isOpen'))
                _StatusChip(isOpen ? 'Enquiry in progress' : 'Closed',
                  color: isOpen ? Colors.green : Colors.red),
              if (data.containsKey('teamsCanRespond') && teamsCanRespond)
                const _StatusChip('Competitors may respond', color: Colors.green),
              if (data.containsKey('teamsCanComment') && teamsCanComment)
                const _StatusChip('Competitors may comment on responses', color: Colors.green),
              if (data.containsKey('teamsCanRespond') && data.containsKey('teamsCanComment') && !teamsCanRespond && !teamsCanComment)
                const _StatusChip('Under review by Rules Committee', color: Colors.orange),
                ],
              ),

          // COMMENTARY
          commentary: postText.isEmpty ? null : SelectableText(postText),

          // ATTACHMENTS
          attachments: attachments.map((m) => FancyAttachmentTile.fromMap(
            m,
            previewHeight: MediaQuery.of(context).size.height * 0.6,
            )).toList(), // consider making platform dependent

          // CHILDREN: Responses list + New child
          footer: _ChildrenSection.responses(enquiryId: enquiryId),

        );
      },
    );
  }
}

/// -------------------- RESPONSE DETAIL --------------------
class ResponseDetailPage extends StatelessWidget {
  const ResponseDetailPage({
    super.key,
    required this.enquiryId,
    required this.responseId,
  });

  final String enquiryId;
  final String responseId;

  @override
  Widget build(BuildContext context) {
    final respRef = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    final enquiryRef = respRef.parent.parent! // -> DocumentReference to 'enquiries/{enquiryId}'
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: respRef.snapshots(),
      builder: (context, respSnap) {
        if (respSnap.hasError) return const Center(child: Text('Failed to load response'));
        if (!respSnap.hasData) return const Center(child: CircularProgressIndicator());
        final response = respSnap.data!.data() ?? {};

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: enquiryRef.snapshots(),
          builder: (context, enqSnap) {
            if (enqSnap.hasError) return const Center(child: Text('Failed to load enquiry'));
            if (!enqSnap.hasData) return const Center(child: CircularProgressIndicator());
            final enquiry = enqSnap.data!.data() ?? {};

            // --- response fields---
            final text = (response['postText'] ?? '').toString().trim();
            final roundNumber = (response['roundNumber'] ?? 'x').toString();
            final responseNumber = (response['responseNumber'] ?? 'x').toString();
            final attachments =
                (response['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

            // --- enquiry fields ---
            final enquiryNumber = (enquiry['enquiryNumber'] ?? 'x').toString();
            final isOpen = enquiry['isOpen'] == true;
            final currentRound = enquiry['roundNumber'] == response['roundNumber'];
            final teamsCanComment = enquiry['teamsCanComment'] == true;

            return _DetailScaffold(
              headerLines: ['RE #$enquiryNumber - Response $roundNumber.$responseNumber'],
              meta: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (enquiry.containsKey('isOpen'))
                    _StatusChip(isOpen ? 'Enquiry in progress' : 'Enquiry closed',
                      color: isOpen ? Colors.green : Colors.red),
                  if (enquiry.containsKey('roundNumber') && response.containsKey('roundNumber')) ...[
                    _StatusChip(currentRound ? 'Round in progress' : 'Round closed',
                      color: currentRound ? Colors.green : Colors.red),
                    if (response.containsKey('teamsCanComment') && teamsCanComment)
                      _StatusChip(teamsCanComment ? 'Competitors may comment' : 'Comments closed', 
                      color: teamsCanComment ? Colors.green : Colors.red),
                  ],
                ],
              ),
            // COMMENTARY
            commentary: text.isEmpty ? null : SelectableText(text),
            // ATTACHMENTS
            attachments: attachments.map((m) => FancyAttachmentTile.fromMap(
              m,
              previewHeight: MediaQuery.of(context).size.height * 0.6,
              )).toList(), // consider making platform dependent

            // CHILDREN: Comments list + New child
            footer: _ChildrenSection.comments(enquiryId: enquiryId, responseId: responseId),
            );
          },
        );
      },
    );
  }
}


/// -------------------- SHARED DETAIL SCAFFOLD (Card-based) --------------------
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.headerLines,
    required this.meta,
    this.subHeaderLines = const <String>[],
    this.commentary,
    this.attachments = const <Widget>[],
    this.footer,
  });

  final List<String> headerLines;
  final List<String> subHeaderLines;
  final Widget meta;               // usually MetaChips (+ optional status chips)
  final Widget? commentary;        // null => hide section
  final List<Widget> attachments;  // empty => hide section
  final Widget? footer;            // usually Children card; null => hide

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // HEADER CARD
          _SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: title(s) + trailing actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HeaderBlock(
                        headerLines: headerLines,
                        subHeaderLines: subHeaderLines,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                meta,
              ],
            ),
          ),

          // CONTENT CARD (optional)
          if (commentary != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Content',
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: commentary!,
              ),
            ),
          ],

          // ATTACHMENTS CARD (optional)
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Attachments',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in attachments) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: w,
                  ),
                ],
              ),
            ),
          ],

          // FOOTER (usually children section card)
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.headerLines, required this.subHeaderLines});
  final List<String> headerLines;
  final List<String> subHeaderLines;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in headerLines) Text(line, style: t.titleLarge),
        if (subHeaderLines.isNotEmpty) const SizedBox(height: 4),
        for (final sub in subHeaderLines) Text(sub, style: t.titleMedium),
      ],
    );
  }
}

/// -------------------- CHILDREN SECTION (Responses / Comments) --------------------
class _ChildrenSection extends StatelessWidget {
  const _ChildrenSection._({
    required this.title,
    required this.builder,
    required this.newChildButton,
  });

  factory _ChildrenSection.responses({required String enquiryId}) {
    return _ChildrenSection._(
      title: 'Responses',
      newChildButton: Align(
        alignment: Alignment.centerLeft,
        child: NewPostButton(
          type: PostType.response,
          parentIds: [enquiryId],
        ),
      ),
      builder: (context) {
        final q = FirebaseFirestore.instance
            .collection('enquiries')
            .doc(enquiryId)
            .collection('responses')
            .where('isPublished', isEqualTo: true)
            .orderBy('publishedAt', descending: true);
        return q.snapshots().map((s) => s.docs);
      },
    );
  }

  factory _ChildrenSection.comments({
    required String enquiryId,
    required String responseId,
  }) {
    return _ChildrenSection._(
      title: 'Comments',
      newChildButton: Align(
        alignment: Alignment.centerLeft,
        child: NewPostButton(
          type: PostType.comment,
          parentIds: [enquiryId, responseId],
        ),
      ),
      builder: (context) {
        final q = FirebaseFirestore.instance
            .collection('enquiries')
            .doc(enquiryId)
            .collection('responses')
            .doc(responseId)
            .collection('comments')
            .where('isPublished', isEqualTo: true)
            .orderBy('publishedAt', descending: true);
        return q.snapshots().map((s) => s.docs);
      },
    );
  }

  final String title;
  final Widget newChildButton;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> Function(BuildContext) builder;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      trailing: newChildButton,
      child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: builder(context),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Firestore stream error: ${snap.error}');
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Failed to load items'),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs = snap.data!;
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No items yet'),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              final t = (d['publishedAt'] as Timestamp?)?.toDate();
              final text = (d['postText'] ?? '').toString().trim();
              final snippet = text.isEmpty
                  ? '…'
                  : (text.length > 140 ? '${text.substring(0, 140)}…' : text);

              // Determine route target based on collection depth
              final segments = docs[i].reference.path.split('/');
              Widget? tile;
              if (segments.contains('responses') && !segments.contains('comments')) {
                // Response item (child of enquiry)
                final enquiryId = segments[1];
                final responseId = id;
                tile = ListTile(
                  subtitle: Text(snippet),
                  trailing: Text(t == null ? '' : _fmtRelativeTime(t)),
                  onTap: () => context.go('/enquiries/$enquiryId/responses/$responseId'),
                );
              } else if (segments.contains('comments')) {
                tile = Card(
                  child: ExpandableCommentTile(snippet, maxLines: 3),
                );
              }
              return tile ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

/// -------------------- PRESENTATION HELPERS --------------------
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || trailing != null) ...[
              Row(
                children: [
                  if (title != null)
                    Text(title!, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const Divider(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, {this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? Colors.blueGrey).withOpacity(0.12);
    final fg = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      side: BorderSide(color: (color ?? Colors.black12).withOpacity(0.2)),
      labelStyle: TextStyle(color: fg),
      visualDensity: VisualDensity.compact,
    );
  }
}

class ExpandableCommentTile extends StatefulWidget {
  const ExpandableCommentTile(
    this.text, {
    super.key,
    this.maxLines = 3,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final String text;
  final int maxLines;
  final EdgeInsetsGeometry padding;

  @override
  State<ExpandableCommentTile> createState() => _ExpandableCommentTileState();
}

class _ExpandableCommentTileState extends State<ExpandableCommentTile> {
  bool _isOverflowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Measure once to see if it exceeds maxLines.
    final style = DefaultTextStyle.of(context).style;
    final width = MediaQuery.of(context).size.width -
        (widget.padding is EdgeInsets ? (widget.padding as EdgeInsets).horizontal : 32);

    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);

    _isOverflowing = tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = Text(
      widget.text,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );

    if (!_isOverflowing) {
      // Simple non-expandable "tile"
      return Padding(
        padding: widget.padding,
        child: collapsed,
      );
    }

    // Expandable, ListTile-like
    return ExpansionTile(
      tilePadding: widget.padding,
      childrenPadding: EdgeInsets.only(
        left: (widget.padding is EdgeInsets) ? (widget.padding as EdgeInsets).left : 16,
        right: (widget.padding is EdgeInsets) ? (widget.padding as EdgeInsets).right : 16,
        bottom: (widget.padding is EdgeInsets) ? (widget.padding as EdgeInsets).bottom : 12,
      ),
      title: collapsed, // truncated preview
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(widget.text), // full text
        ),
      ],
    );
  }
}



/// -------------------- META CHIPS ROW --------------------
class MetaChips extends StatelessWidget {
  const MetaChips({super.key, required this.chips});
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

/// -------------------- UTIL --------------------
String _fmtRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
