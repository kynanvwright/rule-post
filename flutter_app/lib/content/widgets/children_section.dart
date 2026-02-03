// flutter_app/lib/content/widgets/children_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/content/widgets/list_tile.dart';
import 'package:rule_post/content/widgets/parse_hex_colour.dart';
import 'package:rule_post/content/widgets/section_card.dart';
import 'package:rule_post/core/buttons/new_post_button.dart' show NewPostButton;
import 'package:rule_post/core/buttons/edit_post_button.dart' show EditPostButton;
import 'package:rule_post/core/models/post_types.dart';
import 'package:rule_post/core/models/types.dart' show DocView;
import 'package:rule_post/navigation/nav.dart';
import 'package:rule_post/riverpod/post_streams.dart';
import 'package:rule_post/core/widgets/unread_dot.dart';
import 'package:rule_post/riverpod/user_detail.dart';
import 'package:rule_post/riverpod/draft_provider.dart';
import 'package:rule_post/debug/debug.dart';


// Used in the detail pages to show tiles of the child posts (responses or comments).
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
            if (!isLoggedIn) return const SizedBox.shrink(); // empty widget when logged out

            if (lockedResponses) {
              return NewPostButton(
                type: PostType.response,
                parentIds: [enquiryId],
                isLocked: true,
                lockedReason: lockedReason,
              );
            }

            // If button is unlocked, check for existing response drafts and lock new post button if found
            final teamId = ref.watch(teamProvider);
            final hasDraft = teamId == null
              ? false
              : ref
                .watch(hasResponseDraftProvider((enquiryId: enquiryId, teamId: teamId)))
                .valueOrNull;
            final isLockedNow = hasDraft == true;
            final reasonNow = isLockedNow
                ? 'Your team already has a response draft for this enquiry.'
                : '';
            return NewPostButton(
              type: PostType.response,
              parentIds: [enquiryId],
              isLocked: isLockedNow,
              lockedReason: reasonNow,
            );
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
            d('Firestore stream error: ${snap.error}');
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
              final segments = docs[i].reference.path.split('/');
              final enquiryId = segments.length > 1 ? segments[1] : '';
              final responseId = segments.length > 3 ? segments[3] : '';
              final title = (d['title'] ?? '').toString().trim();
              final text = (d['postText'] ?? '').toString().trim();
              final roundNumber = (d['roundNumber'] ?? 'x').toString().trim();
              final responseNumber = (d['responseNumber'] ?? 'x').toString().trim();
              final fromRC = d['fromRC'] ?? false;
              final isPublished = d['isPublished'] ?? false;
              final publishedAt = d['publishedAt'];
              final teamColourHex = d['colour'];
              final Color teamColourFaded = teamColourHex == null
                  ? Colors.transparent
                  : parseHexColour(teamColourHex).withValues(alpha: 0.2);

              Widget? tile;
              if (segments.contains('responses') && !segments.contains('comments')) {
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
                  title: Row(
                    children: [
                      Text(!isPublished
                        ? 'Response $roundNumber.$responseNumber (Draft)'
                        : 'Response $roundNumber.$responseNumber',
                      ),
                      UnreadDot(id),
                    ],
                  ),
                  subtitle: titleSnippet == null ? null : Text(titleSnippet),
                  trailing: trailingText,
                  onTap: () => Nav.goResponse(context, enquiryId, responseId),
                );
              } else if (segments.contains('comments')) {
                tile = ListTileCollapsibleText(
                  isPublished ? text : '(Draft) $text',
                  maxLines: 3,
                  sideWidget: isPublished 
                    ? publishedAtSideWidget(publishedAt) 
                    : EditPostButton( // allow comment editing
                        type: PostType.comment,
                        postId: id,
                        initialText: text,
                        parentIds: [enquiryId, responseId],
                        isPublished: isPublished,
                      ),
                  // sideWidget: UnreadDot(id), // not working because data is deleted before it loads
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