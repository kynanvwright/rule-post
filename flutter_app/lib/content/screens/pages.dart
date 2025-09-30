import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/fancy_attachment_tile.dart';
import '../widgets/new_post_button.dart';
import '../../riverpod/post_alias.dart';
import '../../riverpod/user_detail.dart';

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
    final refDoc = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return Consumer(
      builder: (context, ref, _) {

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: refDoc.snapshots(),
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
            final userTeam = ref.watch(teamProvider);
            final isRC = userTeam == 'RC';
            final lockedResponses = (isRC && teamsCanRespond) || (!isRC && (!isOpen || !teamsCanRespond));
            final lockedResponseReason = !lockedResponses
              ? ''
                : isRC
                  ? 'Competitor response window currently open'
                    : !data['isOpen']
                      ? 'Enquiry closed'
                        : 'Responses currently closed';

            // Record latest visit (runs after this frame to avoid write-in-build)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(latestVisitProvider.notifier).state = LatestVisit(
                enquiryId: enquiryId,
                enquiryAlias: 'RE #$enquiryNumber',
              );
            });   

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
              footer: _ChildrenSection.responses(
                enquiryId: enquiryId,
                lockedResponses: lockedResponses,
                lockedReason: lockedResponseReason
                ),
            );
          },
        );
      }
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

    return Consumer(
      builder: (context, ref, _) {

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
                final summary = (response['title'] ?? '').toString().trim();
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
                final userTeam = ref.watch(teamProvider);
                final isRC = userTeam == 'RC';
                final lockedComments = isRC || !isOpen || !currentRound || !teamsCanComment;
                final lockedCommentReason = !lockedComments
                  ? ''
                    : isRC
                      ? 'Rules Committee may not comment'
                        : !isOpen
                          ? 'Enquiry closed'
                            : !currentRound
                              ? 'This round is closed'
                                : 'Comments currently closed';

                // Record latest visit (runs after this frame to avoid write-in-build)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(latestVisitProvider.notifier).state = LatestVisit(
                    enquiryId: enquiryId,
                    enquiryAlias: 'RE #$enquiryNumber',
                    responseId: responseId,
                    responseAlias: 'Response $roundNumber.$responseNumber',
                  );
                });   

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
                // SUMMARY
                summary: summary.isEmpty ? null : SelectableText(summary),
                // COMMENTARY
                commentary: text.isEmpty ? null : SelectableText(text),
                // ATTACHMENTS
                attachments: attachments.map((m) => FancyAttachmentTile.fromMap(
                  m,
                  previewHeight: MediaQuery.of(context).size.height * 0.6,
                  )).toList(), // consider making platform dependent

                // CHILDREN: Comments list + New child
                footer: _ChildrenSection.comments(
                  enquiryId: enquiryId, 
                  responseId: responseId,
                  lockedComments: lockedComments,
                  lockedReason: lockedCommentReason,),
                );
              },
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
    this.summary,
    this.commentary,
    this.attachments = const <Widget>[],
    this.footer,
  });

  final List<String> headerLines;
  final List<String> subHeaderLines;
  final Widget meta;               // usually MetaChips (+ optional status chips)
  final Widget? summary;        // null => hide section
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
          if (summary != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Summary',
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: summary!,
              ),
            ),
          ],

          // CONTENT CARD (optional)
          if (commentary != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Details',
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

  factory _ChildrenSection.responses({
    required String enquiryId,
    bool lockedResponses = false,
    String lockedReason = '',
  }) {
    return _ChildrenSection._(
      title: 'Responses',
      newChildButton: Align(
        alignment: Alignment.centerLeft,
        child: Consumer(
          builder: (context, ref, _) {
            final isLoggedIn = ref.watch(isLoggedInProvider);
            return isLoggedIn
              ? NewPostButton(
              type: PostType.response,
              parentIds: [enquiryId],
              isLocked: lockedResponses,
              lockedReason: lockedReason,
            )
            : const SizedBox.shrink(); // empty widget when logged out
          },
        ),
      ),
      builder: (context) {
        final q = FirebaseFirestore.instance
            .collection('enquiries')
            .doc(enquiryId)
            .collection('responses')
            .where('isPublished', isEqualTo: true)
            .orderBy('publishedAt', descending: false);
        return q.snapshots().map((s) => s.docs);
      },
    );
  }

  factory _ChildrenSection.comments({
    required String enquiryId,
    required String responseId,
    bool lockedComments = false,
    String lockedReason = '',
  }) {
    return _ChildrenSection._(
      title: 'Comments',
      newChildButton: Align(
        alignment: Alignment.centerLeft,
        child: Consumer(
          builder: (context, ref, _) {
            final isLoggedIn = ref.watch(isLoggedInProvider);
            return isLoggedIn
              ? NewPostButton(
                type: PostType.comment,
                parentIds: [enquiryId, responseId],
                isLocked: lockedComments,
                lockedReason: lockedReason,
            )
            : const SizedBox.shrink(); // empty widget when logged out
          },
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
            .orderBy('publishedAt', descending: false);
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
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              final t = (d['publishedAt'] as Timestamp?)?.toDate();
              final title = (d['title'] ?? '').toString().trim();
              final text = (d['postText'] ?? '').toString().trim();
              final roundNumber = (d['roundNumber'] ?? 'x').toString().trim();
              final responseNumber = (d['responseNumber'] ?? 'x').toString().trim();
              final fromRC = d['fromRC'] ?? false;

              final segments = docs[i].reference.path.split('/');
              final teamColourHex = d['colour'];
              final Color teamColourFaded = teamColourHex == null
                  ? Colors.transparent
                  : parseHexColour(teamColourHex).withValues(alpha: 0.2);

              Widget? tile;
              if (segments.contains('responses') && !segments.contains('comments')) {
                final enquiryId = segments[1];
                final responseId = id;
                final titleSnippet = title.isEmpty
                    ? null
                    : (title.length > 140 ? '${title.substring(0, 140)}…' : title);

                tile = ListTile(
                  title: fromRC 
                  ? Text('Response $roundNumber.$responseNumber (Rules Committee)') 
                  : Text('Response $roundNumber.$responseNumber'),
                  subtitle: titleSnippet == null ? null : Text(titleSnippet),
                  trailing: Text(t == null ? '' : _fmtRelativeTime(t)),
                  onTap: () => context.go('/enquiries/$enquiryId/responses/$responseId'),
                );
              } else if (segments.contains('comments')) {
                tile = ListTileCollapsibleText(
                  text,
                  maxLines: 3,
                );
              }

              if (tile == null) return const SizedBox.shrink();

              return Card(
                color: teamColourFaded,
                elevation: 0, // 🚫 no shadow
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                surfaceTintColor: Colors.transparent, // avoids Material3 tint
                child: tile,
              );
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
/// -------------------- COLLAPSIBLE TEXT (for comments) --------------------
class ListTileCollapsibleText extends StatefulWidget {
  const ListTileCollapsibleText(
    this.text, {
    super.key,
    this.maxLines = 3,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.showCollapsedHint = true,
    this.tileColor, // NEW: mimic ListTile.tileColor
  });

  final String text;
  final int maxLines;
  final EdgeInsetsGeometry contentPadding;
  final bool showCollapsedHint;
  final Color? tileColor; // NEW

  @override
  State<ListTileCollapsibleText> createState() => _ListTileCollapsibleTextState();
}

class _ListTileCollapsibleTextState extends State<ListTileCollapsibleText>
    with TickerProviderStateMixin {
  bool _expanded = false;
  bool _overflows = false;

  void _checkOverflow(
    BoxConstraints c,
    TextStyle style,
    TextDirection dir,
    EdgeInsets resolvedPad,
  ) {
    final maxWidth = c.maxWidth - resolvedPad.horizontal;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: dir,
    )..layout(maxWidth: maxWidth > 0 ? maxWidth : 0);
    _overflows = tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listTileTheme = ListTileTheme.of(context);
    final dir = Directionality.of(context);
    final textStyle = theme.textTheme.bodyMedium!;
    final iconColor = listTileTheme.iconColor ?? theme.iconTheme.color;
    final resolvedPad = widget.contentPadding.resolve(dir);

    return LayoutBuilder(
      builder: (context, constraints) {
        _checkOverflow(constraints, textStyle, dir, resolvedPad);

        return Material(
          // NEW: allow background colour like ListTile.tileColor
          color: widget.tileColor ?? Colors.transparent,
          child: InkWell(
            onTap: _overflows ? () => setState(() => _expanded = !_expanded) : null,
            // DEPRECATION: MaterialStateProperty -> WidgetStateProperty
            overlayColor: WidgetStateProperty.resolveWith((states) {
              final base = theme.colorScheme.onSurface;
              // DEPRECATION: withOpacity -> withValues(alpha: ...)
              if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
                return base.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return base.withValues(alpha: 0.04);
              }
              return null;
            }),
            child: Padding(
              padding: resolvedPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.text,
                            style: textStyle,
                            maxLines: _expanded ? null : widget.maxLines,
                            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (_overflows) ...[
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 160),
                          turns: _expanded ? 0.5 : 0.0,
                          child: Icon(Icons.expand_more, size: 24, color: iconColor),
                        ),
                      ],
                    ],
                  ),
                  if (_overflows && !_expanded && widget.showCollapsedHint) ...[
                    const SizedBox(height: 4),
                    Text(
                      "…",
                      style: textStyle.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Semantics(
                    button: true,
                    expanded: _expanded,
                    label: _expanded ? 'Collapse' : 'Expand',
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

Color parseHexColour(String hex) {
  final s = hex.replaceFirst('#', '');
  final argb = (s.length == 6) ? 'FF$s' : s; // add alpha if needed
  return Color(int.parse(argb, radix: 16));
}
