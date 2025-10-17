import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/children_section.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/fancy_attachment_tile.dart';
import '../widgets/status_chip.dart';

import '../../riverpod/post_alias.dart';
import '../../riverpod/user_detail.dart';

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
                final fromRC = response['fromRC'] ?? false;
                final isPublished = response['isPublished'] ?? false;

                // --- enquiry fields ---
                final enquiryNumber = (enquiry['enquiryNumber'] ?? 'x').toString();
                final isOpen = enquiry['isOpen'] ?? false;
                final currentRound = enquiry['roundNumber'] == response['roundNumber'];
                final teamsCanComment = enquiry['teamsCanComment'] ?? false;
                final userTeam = ref.watch(teamProvider);
                final isRC = userTeam == 'RC';
                final lockedComments = !isPublished || isRC || fromRC || !isOpen || !currentRound || !teamsCanComment;
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

                // Record latest visit (runs after this frame to avoid write-in-build)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(responseAliasProvider((enquiryId: enquiryId, responseId: responseId)).notifier).state =
                    'Response $roundNumber.$responseNumber';
                });   

                return DetailScaffold(
                  headerLines: ['Response $roundNumber.$responseNumber'],
                  subHeaderLines: ['Rule Enquiry #$enquiryNumber'],
                  meta: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (enquiry.containsKey('isOpen') && !isOpen)
                        StatusChip('Enquiry closed', color: Colors.red)
                      else if (response.containsKey('isPublished') && !isPublished) 
                        StatusChip('Unpublished', color: Colors.orange)
                      else if (enquiry.containsKey('roundNumber') && response.containsKey('roundNumber') && !currentRound)
                        StatusChip('Round closed', color: Colors.red)
                      else if (enquiry.containsKey('teamsCanComment') && !fromRC)
                        StatusChip(teamsCanComment ? 'Competitors may comment' : 'Comments closed', 
                        color: teamsCanComment ? Colors.green : Colors.red),
                      
                      if (response.containsKey('fromRC') && fromRC)
                        const StatusChip('Rules Committee Response', color: Colors.blue),
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
                footer: fromRC
                  ? null
                  : ChildrenSection.comments(
                      enquiryId: enquiryId,
                      responseId: responseId,
                      lockedComments: lockedComments,
                      lockedReason: lockedCommentReason,
                    ),
                );
              },
            );
          },
        );
      },
    );
  }
}

