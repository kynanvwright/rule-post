// flutter_app/lib/content/screens/response_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/content/widgets/author_tag.dart'
    show formatAuthorSuffix;
import 'package:rule_post/content/widgets/children_section.dart';
import 'package:rule_post/content/widgets/detail_scaffold.dart';
import 'package:rule_post/content/widgets/fancy_attachment_tile.dart';
import 'package:rule_post/content/widgets/parse_hex_colour.dart';
import 'package:rule_post/content/widgets/status_chip.dart';
import 'package:rule_post/core/buttons/edit_post_button.dart';
import 'package:rule_post/core/buttons/delete_post_button.dart';
import 'package:rule_post/core/models/post_types.dart';
import 'package:rule_post/core/widgets/markdown_display.dart';
import 'package:rule_post/debug/debug.dart' as debug;
import 'package:rule_post/riverpod/admin_providers.dart';
import 'package:rule_post/riverpod/doc_providers.dart';
import 'package:rule_post/riverpod/read_receipts.dart';
import 'package:rule_post/riverpod/user_detail.dart';

/// -------------------- RESPONSE DETAIL --------------------
class ResponseDetailPage extends ConsumerStatefulWidget {
  const ResponseDetailPage({
    super.key,
    required this.enquiryId,
    required this.responseId,
  });
  final String enquiryId;
  final String responseId;

  @override
  ConsumerState<ResponseDetailPage> createState() => _ResponseDetailPageState();
}

class _ResponseDetailPageState extends ConsumerState<ResponseDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final markResponsesAndCommentsRead = ref.read(
        markResponsesAndCommentsReadProvider,
      );
      markResponsesAndCommentsRead?.call(widget.enquiryId, widget.responseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final eAsync = ref.watch(enquiryDocProvider(widget.enquiryId));
    final rAsync = ref.watch(
      responseDocProvider((
        enquiryId: widget.enquiryId,
        responseId: widget.responseId,
      )),
    );
    final userTeam = ref.watch(teamProvider);
    final authorsAsync = ref.watch(postAuthorsProvider(widget.enquiryId));

    // Use idiomatic nested .when() pattern: load enquiry, then response
    return eAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Failed to load enquiry')),
      data: (e) => rAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load response')),
        data: (r) {
          final enquiryData = e ?? const <String, dynamic>{};
          final responseData = r ?? const <String, dynamic>{};
          // Validate schemas: warn if expected keys are missing
          debug.validateDocSchema(
            e,
            ['enquiryNumber', 'isOpen', 'isPublished'],
            docType: 'Enquiry',
            docId: widget.enquiryId,
          );
          debug.validateDocSchema(
            r,
            [
              'title',
              'postText',
              'roundNumber',
              'responseNumber',
              'isPublished',
            ],
            docType: 'Response',
            docId: widget.responseId,
          );

          // --- response fields---
          final summary = (responseData['title'] ?? '').toString().trim();
          final text = (responseData['postText'] ?? '').toString().trim();
          final roundNumber = (responseData['roundNumber'] ?? 'x').toString();
          final responseNumber = (responseData['responseNumber'] ?? 'x')
              .toString();
          final attachments =
              (responseData['attachments'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              const [];
          final fromRC = responseData['fromRC'] ?? false;
          final isPublished = responseData['isPublished'] ?? false;
          final teamColourHex = responseData['colour'];
          final Color teamColourFaded = teamColourHex == null
              ? Colors.transparent
              : parseHexColour(teamColourHex).withValues(alpha: 0.2);

          // --- enquiry fields ---
          final enquiryNumber = (enquiryData['enquiryNumber'] ?? 'x')
              .toString();
          final isOpen = enquiryData['isOpen'] ?? false;
          final currentRound =
              enquiryData['roundNumber'] == enquiryData['roundNumber'];
          final teamsCanComment = enquiryData['teamsCanComment'] ?? false;
          final isRC = userTeam == 'RC';

          // Extract response author from cache (safely handle all async states)
          final responseAuthorTeam = authorsAsync.maybeWhen(
            data: (authors) => authors?[widget.responseId],
            orElse: () => null,
          );

          final lockedComments =
              !isPublished ||
              isRC ||
              fromRC ||
              !isOpen ||
              !currentRound ||
              !teamsCanComment;
          final lockedCommentReason = !lockedComments
              ? ''
              : !isPublished
              ? "Can't comment on unpublished response"
              : isRC
              ? 'Rules Committee may not comment'
              : fromRC
              ? 'No comments on Rules Committee responses'
              : !isOpen
              ? 'Enquiry closed'
              : !currentRound
              ? 'This round is closed'
              : 'Comments currently closed';
          return DetailScaffold(
            headerLines: [
              'Response $roundNumber.$responseNumber${formatAuthorSuffix(responseAuthorTeam)}',
            ],
            subHeaderLines: [
              'Rule Enquiry ${enquiryNumber.toString().padLeft(3, '0')}',
            ],
            headerButton: isPublished
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EditPostButton(
                        type: PostType.response,
                        initialTitle: summary,
                        initialText: text,
                        initialAttachments: attachments,
                        postId: widget.responseId,
                        parentIds: [widget.enquiryId],
                        isPublished: isPublished,
                        initialCloseEnquiryOnPublish:
                            responseData['closeEnquiryOnPublish'] ?? false,
                        initialEnquiryConclusion:
                            responseData['enquiryConclusion']?.toString(),
                      ),
                      const SizedBox(width: 8),
                      DeletePostButton(
                        type: PostType.response,
                        postId: widget.responseId,
                        parentIds: [widget.enquiryId],
                      ),
                    ],
                  ),
            headerColour: teamColourFaded,
            meta: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (enquiryData.containsKey('isOpen') && !isOpen)
                  StatusChip('Enquiry closed', color: Colors.red)
                else if (responseData.containsKey('isPublished') &&
                    !isPublished)
                  StatusChip('Unpublished', color: Colors.orange)
                else if (enquiryData.containsKey('roundNumber') &&
                    responseData.containsKey('roundNumber') &&
                    !currentRound)
                  StatusChip('Round closed', color: Colors.red)
                else if (enquiryData.containsKey('teamsCanComment') && !fromRC)
                  StatusChip(
                    teamsCanComment
                        ? 'Competitors may comment'
                        : 'Comments closed',
                    color: teamsCanComment ? Colors.green : Colors.red,
                  ),

                if (responseData.containsKey('fromRC') && fromRC)
                  const StatusChip(
                    'Rules Committee Response',
                    color: Colors.blue,
                  ),
              ],
            ),

            // SUMMARY
            summary: summary.isEmpty ? null : MarkdownDisplay(summary),
            // COMMENTARY
            commentary: text.isEmpty ? null : MarkdownDisplay(text),
            // ATTACHMENTS
            attachments: attachments
                .map(
                  (m) => FancyAttachmentTile.fromMap(
                    m,
                    previewHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                )
                .toList(), // consider making platform dependent
            // CHILDREN: Comments list + New child
            footer: fromRC
                ? null
                : ChildrenSection.comments(
                    enquiryId: widget.enquiryId,
                    responseId: widget.responseId,
                    lockedComments: lockedComments,
                    lockedReason: lockedCommentReason,
                    authors: authorsAsync.maybeWhen(
                      data: (a) => a,
                      orElse: () => null,
                    ),
                  ),
          );
        },
      ),
    );
  }
}
