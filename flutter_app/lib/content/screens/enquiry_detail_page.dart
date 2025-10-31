// flutter_app/lib/content/screens/enquiry_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/children_section.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/fancy_attachment_tile.dart';
import '../widgets/rules_committee_panel.dart';
import '../widgets/status_chip.dart';
import '../widgets/new_post_button.dart';
import '../../api/change_stage_length.dart';
import '../../api/close_enquiry_api.dart';
import '../../api/publish_competitor_responses.dart';
import '../../api/publish_rc_response.dart';
import '../../riverpod/doc_providers.dart';
import '../../riverpod/user_detail.dart';


/// -------------------- ENQUIRY DETAIL --------------------
class EnquiryDetailPage extends ConsumerWidget {
  const EnquiryDetailPage({super.key, required this.enquiryId});
  final String enquiryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(enquiryDocProvider(enquiryId));
    final userRole = ref.watch(roleProvider);
    final userTeam = ref.watch(teamProvider);

    return docAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, i_) => const Center(child: Text('Failed to load enquiry')),
      data: (data) {
        final d = data ?? const {};
        final title = (d['title'] ?? 'Untitled').toString();
        final enquiryNumber = (d['enquiryNumber'] ?? '—').toString();
        final postText = (d['postText'] ?? '').toString().trim();
        final attachments = (d['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final isOpen = d['isOpen'] ?? false;
        final isPublished = d['isPublished'] ?? false;
        final teamsCanRespond = d['teamsCanRespond'] ?? false;
        final teamsCanComment = d['teamsCanComment'] ?? false;
        final stageStarts = (d['stageStarts'] as Timestamp?)?.toDate();
        final stageEnds = (d['stageEnds'] as Timestamp?)?.toDate();
        final fromRC = d['fromRC'] ?? false;

        final isAdmin = userRole == 'admin';
        final isRC = userTeam == 'RC';
        final lockedResponses = !isPublished || (isRC && teamsCanRespond) || (!isRC && (!isOpen || !teamsCanRespond));
        final lockedResponseReason = !lockedResponses ? '' :
          !isPublished ? "Can't respond to unpublished enquiry" :
          isRC ? 'Competitor response window currently open' :
          !d['isOpen'] ? 'Enquiry closed' : 'Responses currently closed';

        debugPrint("attachments: $attachments");

        return DetailScaffold(
          headerLines: [title],
          subHeaderLines: ['Rule Enquiry #$enquiryNumber'],
          headerButton: isPublished ? 
          null : 
          EditPostButton(
            type: PostType.enquiry,
            initialTitle: title,
            initialText: postText,
            initialAttachments: attachments,
            postId: enquiryId,
            ),
          meta: Wrap(
            spacing: 8, runSpacing: 8, children: [
              if (d.containsKey('isOpen') && !isOpen && d.containsKey('enquiryConclusion')) StatusChip(enquiryConclusionLabels[d['enquiryConclusion']] ?? 'Closed', color: Colors.red),
              if (d.containsKey('isPublished') && !isPublished) StatusChip('Unpublished', color: Colors.orange),
              if (d.containsKey('fromRC') && fromRC) StatusChip('Rules Committee Enquiry', color: Colors.blue),
            ],
          ),
          stageMap: {
            'teamsCanRespond': teamsCanRespond,
            'teamsCanComment': teamsCanComment,
            'isOpen': isOpen,
            'isPublished': isPublished,
            'stageStarts': stageStarts,
            'stageEnds': stageEnds,
          },
          commentary: postText.isEmpty ? null : SelectableText(postText),
          attachments: attachments.map((m) =>
            FancyAttachmentTile.fromMap(m, previewHeight: MediaQuery.of(context).size.height * 0.6),
          ).toList(),
          footer: ChildrenSection.responses(
            enquiryId: enquiryId,
            lockedResponses: lockedResponses,
            lockedReason: lockedResponseReason,
          ),
          adminPanel: (isRC || isAdmin)
              ? AdminCard(
                  titleColour: Colors.red,
                  boldTitle: true,
                  actions: [
                    AdminAction.changeStageLength(
                      enquiryId: enquiryId,
                      loadCurrent: () => getStageLength(enquiryId),
                      run: (days) => changeStageLength(enquiryId, days),
                      enabled: isOpen,
                      context: context,
                    ),
                    AdminAction.publishCompetitorResponses(
                      enquiryId: enquiryId,
                      run: () => publishCompetitorResponses(enquiryId),
                      enabled: teamsCanRespond && isOpen && isPublished,
                      context: context),
                    AdminAction.publishRCResponse(
                      enquiryId: enquiryId,
                      run: () => publishRcResponse(enquiryId),
                      enabled: !teamsCanRespond && isOpen && isPublished,
                      context: context),
                    AdminAction.closeEnquiry(
                      enquiryId: enquiryId,
                      run: (enquiryConclusion) => closeEnquiry(enquiryId, enquiryConclusion),
                      enabled: isOpen && isPublished,
                      context: context),
                  ],
                )
              : null,
        );
      },
    );
  }
}

final enquiryConclusionLabels = {
  'amendment': 'Amendment closed',
  'interpretation': 'Interpretation closed',
  'noResult': 'Enquiry closed with no result',
};