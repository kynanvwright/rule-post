import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/foundation.dart';

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
        final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate();
        // final author = (data['author'] ?? 'Unknown').toString();
        final attachments = (data['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        // Optional status flags. Only show if present.
        final isOpen = data['isOpen'] == true;
        final lockedToTeams = data['lockedToTeams'] == true; // if false => open to competitors
        final underReview = data['underReview'] == true;

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
              // Chip(label: Text(author)),
              if (publishedAt != null) 
                Chip(label: Text(_fmtDateTime(publishedAt))),
              const SizedBox(height: 16),
              if (data.containsKey('isOpen'))
                _StatusChip(isOpen ? 'Enquiry in progress' : 'Closed',
                  color: isOpen ? Colors.green : Colors.red),
              if (data.containsKey('lockedToTeams') && !lockedToTeams)
                const _StatusChip('Responses/Comments currently open to Competitors'),
              if (underReview) 
                const _StatusChip('Under Review by Rules Committee', color: Colors.orange),
                ],
              ),

          // COMMENTARY
          commentary: postText.isEmpty ? null : SelectableText(postText),

          // ATTACHMENTS
          // attachments: attachments.map((m) => AttachmentTile.fromMap(m)).toList(),
          attachments: attachments.map((m) => FancyAttachmentTile.fromMap(
            m,
            previewHeight: MediaQuery.of(context).size.height * 0.6,
            )).toList(), // consider making platform dependent

          // CHILDREN: Responses list + New child
          footer: _ChildrenSection.responses(enquiryId: enquiryId),

          // trailingActions: [
          //   FilledButton.icon(
          //     onPressed: () => context.go('/enquiries/$enquiryId/responses'),
          //     icon: const Icon(Icons.forum_outlined),
          //     label: const Text('View Responses'),
          //   ),
          // ],
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
    final ref = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Failed to load response'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() ?? {};

        final text = (data['postText'] ?? '').toString().trim();
        final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate();
        // final author = (data['author'] ?? 'Unknown').toString();
        final roundNumber = (data['responseNumber'] ?? 'x').toString();
        final responseNumber = (data['responseNumber'] ?? 'x').toString();
        final attachments = (data['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        // Optional status on parent (bubble up if provided)
        final underReview = data['underReview'] == true;

        return _DetailScaffold(
          headerLines: [
            // 'Rule Enquiry – Response $number',
            // 'Rule Enquiry #$enquiryNumber – $title',
            'Response $roundNumber.$responseNumber'
          ],
          // subHeaderLines: ['Response $roundNumber.$responseNumber'], // keeps the visual rhythm; adjust if you store a label
          meta: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Chip(label: Text(author)),
              if (publishedAt != null) 
                Chip(label: Text(_fmtDateTime(publishedAt))),
              if (underReview) 
                const SizedBox(height: 8),
                const _StatusChip('Under Review by Rules Committee', color: Colors.orange),
            ],
          ),

          commentary: text.isEmpty ? null : SelectableText(text),
          // attachments: attachments.map((m) => AttachmentTile.fromMap(m)).toList(),
          attachments: attachments.map((m) => FancyAttachmentTile.fromMap(
            m,
            previewHeight: MediaQuery.of(context).size.height * 0.6,
            )).toList(), // consider making platform dependent

          // CHILDREN: Comments list + New child
          footer: _ChildrenSection.comments(enquiryId: enquiryId, responseId: responseId),

          // trailingActions: [
          //   FilledButton.icon(
          //     onPressed: () => context.go('/enquiries/$enquiryId/responses/$responseId/comments'),
          //     icon: const Icon(Icons.mode_comment_outlined),
          //     label: const Text('View Comments'),
          //   ),
          // ],
        );
      },
    );
  }
}

/// -------------------- COMMENT DETAIL --------------------
class CommentDetailPage extends StatelessWidget {
  const CommentDetailPage({
    super.key,
    required this.enquiryId,
    required this.responseId,
    required this.commentId,
  });

  final String enquiryId;
  final String responseId;
  final String commentId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .collection('comments')
        .doc(commentId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Failed to load comment'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() ?? {};

        final text = (data['postText'] ?? '').toString().trim();
        final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate();
        // final author = (data['author'] ?? 'Unknown').toString();
        final number = (data['commentNumber'] ?? '—').toString();
        // final attachments = (data['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        return _DetailScaffold(
          headerLines: [
            'Comment #$number',
          ],
          subHeaderLines: const [],

          meta: MetaChips(
            chips: [
              // Chip(label: Text(author)),
              if (publishedAt != null) Chip(label: Text(_fmtDateTime(publishedAt))),
            ],
          ),

          commentary: text.isEmpty ? null : SelectableText(text),
          // attachments: attachments.map((m) => AttachmentTile.fromMap(m)).toList(),

          // Comments have no children section
          footer: null,
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
    this.trailingActions = const <Widget>[],
    this.footer,
  });

  final List<String> headerLines;
  final List<String> subHeaderLines;
  final Widget meta;               // usually MetaChips (+ optional status chips)
  final Widget? commentary;        // null => hide section
  final List<Widget> attachments;  // empty => hide section
  final List<Widget> trailingActions;
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
                    if (trailingActions.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: trailingActions,
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
              // final author = (d['author'] ?? 'Unknown').toString();
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
                  // title: Text(author),
                  subtitle: Text(snippet),
                  trailing: Text(t == null ? '' : _fmtRelativeTime(t)),
                  onTap: () => context.go('/enquiries/$enquiryId/responses/$responseId'),
                );
              } else if (segments.contains('comments')) {
                // Comment item (child of response)
                final enquiryId = segments[1];
                final responseId = segments[3];
                final commentId = id;
                tile = ListTile(
                  // title: Text(author),
                  subtitle: Text(snippet),
                  trailing: Text(t == null ? '' : _fmtRelativeTime(t)),
                  onTap: () => context.go('/enquiries/$enquiryId/responses/$responseId/comments/$commentId'),
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
    super.key,
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
String _fmtDateTime(DateTime dt) {
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}';
}

String _fmtRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String _two(int n) => n.toString().padLeft(2, '0');
