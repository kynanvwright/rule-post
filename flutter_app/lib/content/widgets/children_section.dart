// flutter_app/lib/content/widgets/children_section.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/content/widgets/list_tile.dart';
import 'package:rule_post/content/widgets/parse_hex_colour.dart';
import 'package:rule_post/content/widgets/section_card.dart';
import 'package:rule_post/core/buttons/new_post_button.dart' show NewPostButton;
import 'package:rule_post/core/buttons/edit_post_button.dart' show EditPostButton;
import 'package:rule_post/core/buttons/delete_post_button.dart' show DeletePostButton;
import 'package:rule_post/core/models/post_types.dart';
import 'package:rule_post/core/models/types.dart' show DocView;
import 'package:rule_post/navigation/nav.dart';
import 'package:rule_post/riverpod/post_streams.dart';
import 'package:rule_post/core/widgets/unread_dot.dart';
import 'package:rule_post/riverpod/user_detail.dart';
import 'package:rule_post/riverpod/draft_provider.dart';
import 'package:rule_post/debug/debug.dart';

// Provider for reading the next scheduled comment publication time from Firebase
final nextCommentPublicationTimeProvider =
    StreamProvider<DateTime?>((ref) {
  final db = FirebaseFirestore.instance;
  return db
      .collection('app_data')
      .doc('date_times')
      .snapshots()
      .map((snap) {
    try {
      final raw = snap.get('nextCommentPublicationTime');
      
      if (raw == null) {
        return null;
      }
      
      if (raw is Timestamp) {
        final dt = raw.toDate();
        return dt;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  });
});

// Used in the detail pages to show tiles of the child posts (responses or comments).
class ChildrenSection extends ConsumerWidget {
  const ChildrenSection({
    super.key,
    required this.title,
    required this.contentId,
    required this.builder,
    required this.newChildButton,
    this.authors,
  });

  final Stream<List<DocView>> Function(BuildContext, WidgetRef) builder;
  final Map<String, String>? authors;
  final String contentId;

  factory ChildrenSection.responses({
    required String enquiryId,
    bool lockedResponses = false,
    String lockedReason = '',
    Map<String, String>? authors,
  }) {
    return ChildrenSection(
      title: 'Responses',
      contentId: enquiryId,
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
      authors: authors,
    );
  }

  factory ChildrenSection.comments({
    required String enquiryId,
    required String responseId,
    bool lockedComments = false,
    String lockedReason = '',
    Map<String, String>? authors,
  }) {
    return ChildrenSection(
      title: 'Comments',
      contentId: responseId,
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
      authors: authors,
    );
  }

  final String title;
  final Widget newChildButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Build the stream ONCE (don't call this again for the key)
    final stream = builder(context, ref);
    // 2) Derive key from content ID (enquiryId for responses, responseId for comments)
    //    This ensures key is stable and independent of parent state changes
    final keyForList = ValueKey<String>('$title|$contentId');
    // 4) Read the next publication time ONCE at the widget level (shared across all items)
    final nextPublicationTimeAsync = ref.watch(nextCommentPublicationTimeProvider);
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
              // Use the publication time read at the widget level (not per-item)
              final nextPublicationTime = nextPublicationTimeAsync.maybeWhen(
                data: (dt) => dt,
                orElse: () => null,
              );
              
              final docData = docs[i].data();
              final id = docs[i].id;
              final segments = docs[i].reference.path.split('/');
              final enquiryId = segments.length > 1 ? segments[1] : '';
              final responseId = segments.length > 3 ? segments[3] : '';
              final title = (docData['title'] ?? '').toString().trim();
              final text = (docData['postText'] ?? '').toString().trim();
              final roundNumber = (docData['roundNumber'] ?? 'x').toString().trim();
              final responseNumber = (docData['responseNumber'] ?? 'x').toString().trim();
              final fromRC = docData['fromRC'] ?? false;
              final isPublished = docData['isPublished'] ?? false;
              final publishedAt = docData['publishedAt'];
              final teamColourHex = docData['colour'];
              final Color teamColourFaded = teamColourHex == null
                  ? Colors.transparent
                  : parseHexColour(teamColourHex).withValues(alpha: 0.2);

              Widget? tile;
              if (segments.contains('responses') && !segments.contains('comments')) {
                final titleSnippet = title.isEmpty
                    ? null
                    : (title.length > 140 ? '${title.substring(0, 140)}…' : title);
                final commentCount = docData['commentCount'] ?? 0;

                tile = ListTile(
                  title: Row(
                    children: [
                      Text(!isPublished
                        ? 'Response $roundNumber.$responseNumber (Draft)'
                        : 'Response $roundNumber.$responseNumber${authors?[responseId] != null ? ' (${authors![responseId]})' : ''}',
                      ),
                      UnreadDot(id),
                    ],
                  ),
                  subtitle: titleSnippet == null ? null : Text(titleSnippet),
                  trailing: !isPublished
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EditPostButton(
                            type: PostType.response,
                            postId: responseId,
                            initialTitle: title,
                            initialText: text,
                            parentIds: [enquiryId],
                            isPublished: isPublished,
                          ),
                          const SizedBox(width: 4),
                          DeletePostButton(
                            type: PostType.response,
                            postId: responseId,
                            parentIds: [enquiryId],
                          ),
                        ],
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          fromRC
                            ? 'Rules Committee'
                            : commentCount == 1
                              ? '$commentCount comment  '
                              : '$commentCount comments',
                        ),
                      ),
                  onTap: () => Nav.goResponse(context, enquiryId, responseId),
                );
              } else if (segments.contains('comments')) {
                final author = authors?['${responseId}_$id'];
                final authorSuffix = author != null ? ' ($author)' : '';

                final scheduledText = isPublished 
                  ? text + authorSuffix
                  : '(Draft, scheduled for publication at ${_fmt(nextPublicationTime)})$authorSuffix\n$text';
                
                tile = ListTileCollapsibleText(
                  scheduledText,
                  maxLines: 3,
                  sideWidget: isPublished 
                    ? publishedAtSideWidget(publishedAt) 
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EditPostButton(
                            type: PostType.comment,
                            postId: id,
                            initialText: text,
                            parentIds: [enquiryId, responseId],
                            isPublished: isPublished,
                          ),
                          const SizedBox(width: 4),
                          DeletePostButton(
                            type: PostType.comment,
                            postId: id,
                            parentIds: [enquiryId, responseId],
                          ),
                        ],
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


/// Calculates the next scheduled comment publication time from Firestore.
/// The backend updates this field whenever commentPublisher runs.

String _fmt(DateTime? dt) {
  if (dt == null) return '';
  // Show in local time with short readable format
  return '${dt.day.toString().padLeft(2, '0')} '
      '${_month(dt.month)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}


String _month(int m) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[m - 1];
}