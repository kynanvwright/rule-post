// flutter_app/lib/content/screens/response_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/children_section.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/fancy_attachment_tile.dart';
import '../widgets/status_chip.dart';
import '../../riverpod/doc_providers.dart';
import '../../riverpod/read_receipts.dart';
import '../../riverpod/user_detail.dart';


/// -------------------- RESPONSE DETAIL --------------------
class ResponseDetailPage extends ConsumerStatefulWidget  {
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
      final markResponsesAndCommentsRead = ref.read(markResponsesAndCommentsReadProvider);
      markResponsesAndCommentsRead?.call(widget.enquiryId, widget.responseId);
    });
  }
  @override
  Widget build(BuildContext context) {
    final eAsync = ref.watch(enquiryDocProvider(widget.enquiryId));
    final rAsync = ref.watch(responseDocProvider((enquiryId: widget.enquiryId, responseId: widget.responseId)));
    final userTeam = ref.watch(teamProvider);

        // Unified gate:
    if (eAsync.isLoading || rAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eAsync.hasError)   return const Center(child: Text('Failed to load enquiry'));
    if (rAsync.hasError)  return const Center(child: Text('Failed to load response'));

    final e = eAsync.value ?? const <String, dynamic>{};
    final r = rAsync.value ?? const <String, dynamic>{};

    // --- response fields---
    final summary = (r['title'] ?? '').toString().trim();
    final text = (r['postText'] ?? '').toString().trim();
    final roundNumber = (r['roundNumber'] ?? 'x').toString();
    final responseNumber = (r['responseNumber'] ?? 'x').toString();
    final attachments =
        (r['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final fromRC = r['fromRC'] ?? false;
    final isPublished = r['isPublished'] ?? false;

    // --- enquiry fields ---
    final enquiryNumber = (e['enquiryNumber'] ?? 'x').toString();
    final isOpen = e['isOpen'] ?? false;
    final currentRound = e['roundNumber'] == e['roundNumber'];
    final teamsCanComment = e['teamsCanComment'] ?? false;
    final isRC = userTeam == 'RC';
    final lockedComments = !isPublished || isRC || fromRC || !isOpen || !currentRound || !teamsCanComment;
    final lockedCommentReason = !lockedComments ? '' 
      : !isPublished ? "Can't comment on unpublished response"
      : isRC ? 'Rules Committee may not comment'
      : fromRC ? 'No comments on Rules Committee responses'
      : !isOpen ? 'Enquiry closed'
      : !currentRound ? 'This round is closed'
      : 'Comments currently closed';
    return DetailScaffold(
      headerLines: ['Response $roundNumber.$responseNumber'],
      subHeaderLines: ['Rule Enquiry #$enquiryNumber'],
      meta: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (e.containsKey('isOpen') && !isOpen)
            StatusChip('Enquiry closed', color: Colors.red)
          else if (r.containsKey('isPublished') && !isPublished) 
            StatusChip('Unpublished', color: Colors.orange)
          else if (e.containsKey('roundNumber') && r.containsKey('roundNumber') && !currentRound)
            StatusChip('Round closed', color: Colors.red)
          else if (e.containsKey('teamsCanComment') && !fromRC)
            StatusChip(teamsCanComment ? 'Competitors may comment' : 'Comments closed', 
            color: teamsCanComment ? Colors.green : Colors.red),
          
          if (r.containsKey('fromRC') && fromRC)
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
            enquiryId: widget.enquiryId,
            responseId: widget.responseId,
            lockedComments: lockedComments,
            lockedReason: lockedCommentReason,
          ),
    );
  }
}