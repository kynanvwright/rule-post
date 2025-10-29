import 'package:flutter/material.dart';

import '../widgets/header_block.dart';
import '../widgets/section_card.dart';
import '../widgets/status_card.dart';

/// -------------------- SHARED DETAIL SCAFFOLD (Card-based) --------------------
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.headerLines,
    this.meta,
    this.subHeaderLines = const <String>[],
    this.headerButton,
    this.summary,
    this.commentary,
    this.attachments = const <Widget>[],
    this.footer,
    this.adminPanel,
    this.stageMap,
  });

  final List<String> headerLines;
  final List<String> subHeaderLines;
  final Widget? headerButton;
  final Widget? meta;                   // usually MetaChips (+ optional status chips)
  final Widget? summary;                // null => hide section
  final Widget? commentary;             // null => hide section
  final List<Widget> attachments;       // empty => hide section
  final Widget? footer;                 // usually Children card; null => hide
  final Widget? adminPanel;             // only shows for admins; null => hide
  final Map<String, dynamic>? stageMap; // isOpen, teamsCanRespond, teamsCanComment, stageStarts, stageEnds


  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // HEADER CARD
          SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: title(s) + trailing actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: HeaderBlock(
                        headerLines: headerLines,
                        subHeaderLines: subHeaderLines,
                        trailing: headerButton,
                      ),
                    ),
                  ],
                ),
                if (meta is Wrap && (meta as Wrap).children.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  meta!,
                ],
              ],
            ),
          ),

          // STAGE CARD (optional)
          if (stageMap != null && stageMap!['isOpen'] && stageMap!['isPublished']) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Enquiry Stage',
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: StatusCard(stageMap: stageMap!)
              ),
            ),
          ],

          // CONTENT CARD (optional)
          if (summary != null) ...[
            const SizedBox(height: 12),
            SectionCard(
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
            SectionCard(
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
            SectionCard(
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
          ],

          // ADMIN PANEL
          if (adminPanel != null) ...[
            const SizedBox(height: 12),
            adminPanel!,
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
