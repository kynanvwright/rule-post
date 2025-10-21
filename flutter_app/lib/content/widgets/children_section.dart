import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/new_post_button.dart';
import '../widgets/section_card.dart';
import '../widgets/parse_hex_colour.dart';
import '../widgets/list_tile.dart';
import '../../riverpod/post_streams.dart';
import '../../core/widgets/doc_view.dart';
import '../../navigation/nav.dart';
import '../../riverpod/user_detail.dart';

/// -------------------- CHILDREN SECTION (Responses / Comments) --------------------
class ChildrenSection extends ConsumerWidget {
  const ChildrenSection({
    super.key,
    required this.title,
    required this.builder,
    required this.newChildButton,
  });

  final Stream<List<DocView>> Function(BuildContext, WidgetRef) builder;

  factory ChildrenSection.responses({
    required String enquiryId,
    bool lockedResponses = false,
    String lockedReason = '',
  }) {
    return ChildrenSection(
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
      builder: (context, ref) {
        final teamId = ref.watch(teamProvider);
        return combinedResponsesStream(
          enquiryId: enquiryId,
          teamId: teamId, // null => only public; non-null => merge team drafts
        );
      },
    );
  }

  factory ChildrenSection.comments({
    required String enquiryId,
    required String responseId,
    bool lockedComments = false,
    String lockedReason = '',
    // Map<String, String> filter = const {},
  }) {
    return ChildrenSection(
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
      builder: (context, ref) {
        final teamId = ref.watch(teamProvider);
        return combinedCommentsStream(
          enquiryId: enquiryId,
          responseId: responseId,
          teamId: teamId, // null => only public; non-null => merge team drafts
        );
      },
    );
  }

  final String title;
  final Widget newChildButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Read any deps ONCE (used for the key)
    final teamId = ref.watch(teamProvider);

    // 2) Build the stream ONCE (don’t call this again for the key)
    final stream = builder(context, ref);

    // 3) Use a stable key that DOESN’T include the stream
    final keyForList = ValueKey<String>('$title|$teamId');

    return SectionCard(
      title: title,
      trailing: newChildButton,
      child: StreamBuilder<List<DocView>>(
        key: keyForList,
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData || snap.connectionState != ConnectionState.active) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            debugPrint('Firestore stream error: ${snap.error}');
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Failed to load items'),
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
            separatorBuilder: (_, i_) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              // final t = (d['publishedAt'] as Timestamp?)?.toDate();
              final title = (d['title'] ?? '').toString().trim();
              final text = (d['postText'] ?? '').toString().trim();
              final roundNumber = (d['roundNumber'] ?? 'x').toString().trim();
              final responseNumber = (d['responseNumber'] ?? 'x').toString().trim();
              final fromRC = d['fromRC'] ?? false;
              final isPublished = d['isPublished'] ?? false;

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
                final commentCount = d['commentCount'] ?? 0;
                final trailingText = Text( 
                  fromRC==false 
                    ? commentCount == 1
                      ? '$commentCount comment  '
                      : '$commentCount comments'
                    : 'Rules Committee');

                tile = ListTile(
                  title: !isPublished
                  ? Text('Response $roundNumber.$responseNumber (Draft)')
                  : Text('Response $roundNumber.$responseNumber'),
                  subtitle: titleSnippet == null ? null : Text(titleSnippet),
                  trailing: trailingText,
                  onTap: () => Nav.goResponse(context, enquiryId, responseId),
                );
              } else if (segments.contains('comments')) {
                tile = ListTileCollapsibleText(
                  isPublished ? text : '(Draft) $text',
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
