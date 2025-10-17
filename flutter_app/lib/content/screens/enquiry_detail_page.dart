import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/rules_committee_panel.dart';
import '../widgets/children_section.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/fancy_attachment_tile.dart';
import '../widgets/status_chip.dart';
import '../../api/change_stage_length.dart';
import '../../api/close_enquiry_api.dart';
import '../../api/publish_competitor_responses.dart';
import '../../api/publish_rc_response.dart';

import '../../riverpod/post_alias.dart';
import '../../riverpod/user_detail.dart';


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
            final isOpen = data['isOpen'] ?? false;
            final isPublished = data['isPublished'] ?? false;
            final teamsCanRespond = data['teamsCanRespond'] ?? false;
            final teamsCanComment = data['teamsCanComment'] ?? false;
            final stageStarts = (data['stageStarts'] as Timestamp?)?.toDate();
            final stageEnds = (data['stageEnds'] as Timestamp?)?.toDate();
            final fromRC = data['fromRC'] ?? false;
            final userRole = ref.watch(roleProvider);
            final userTeam = ref.watch(teamProvider);
            final isAdmin = userRole == 'admin';
            final isRC = userTeam == 'RC';
            final lockedResponses = !isPublished || (isRC && teamsCanRespond) || (!isRC && (!isOpen || !teamsCanRespond));
            final lockedResponseReason = !lockedResponses
              ? ''
                : !isPublished
                  ? "Can't respond to unpublished enquiry"
                    : isRC
                      ? 'Competitor response window currently open'
                        : !data['isOpen']
                          ? 'Enquiry closed'
                            : 'Responses currently closed';

            // Record latest visit (runs after this frame to avoid write-in-build)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(enquiryAliasProvider(enquiryId).notifier).state = 'RE #${data["enquiryNumber"]}';
            });   

            return DetailScaffold(
              // HEADER (within a card)
              headerLines: [
                title,
              ],
              subHeaderLines: ['Rule Enquiry #$enquiryNumber'], // enquiries themselves don’t need a subheader
              // META (chips row under header)
              meta: 
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (data.containsKey('isOpen') && !isOpen) 
                    StatusChip('Closed', color: Colors.red),
                  if (data.containsKey('isPublished') && !isPublished) 
                    StatusChip('Unpublished', color: Colors.orange),
                  if (data.containsKey('fromRC') && fromRC) 
                    StatusChip('Rules Committee Enquiry', color: Colors.blue),
                  
                ],
              ),
              stageMap: {
                'teamsCanRespond': teamsCanRespond, 
                'teamsCanComment': teamsCanComment, 
                'isOpen': isOpen, 
                'isPublished': isPublished, 
                'stageStarts': stageStarts, 
                'stageEnds': stageEnds},

              // COMMENTARY
              commentary: postText.isEmpty ? null : SelectableText(postText),

              // ATTACHMENTS
              attachments: attachments.map((m) => FancyAttachmentTile.fromMap(
                m,
                previewHeight: MediaQuery.of(context).size.height * 0.6,
                )).toList(), // consider making platform dependent

              // CHILDREN: Responses list + New child
              footer: ChildrenSection.responses(
                enquiryId: enquiryId,
                lockedResponses: lockedResponses,
                lockedReason: lockedResponseReason
                ),

              // ADMIN PANEL
              adminPanel: isRC || isAdmin 
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
                  run: () => closeEnquiry(enquiryId),
                  enabled: isOpen && isPublished,
                  context: context),
              ],
            ) : null,
            );
          },
        );
      }
    );
  }
}
