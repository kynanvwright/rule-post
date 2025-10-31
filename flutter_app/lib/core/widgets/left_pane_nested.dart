import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/widgets/new_post_button.dart';
import '../../navigation/nav.dart';
import '../../riverpod/user_detail.dart';
import '../../riverpod/enquiry_filter_provider.dart';
import '../../riverpod/post_providers.dart';
import '../widgets/doc_view.dart';
import 'filter_dropdown.dart';
import 'two_panel_shell.dart';
import '../models/enquiry_status_filter.dart';

final filterDefault = 'open';

/// ─────────────────────────────────────────────────────────────────────────
/// Left header: title + status chips + debounced search + "New" button
/// ─────────────────────────────────────────────────────────────────────────
class LeftPaneHeader extends ConsumerWidget {
  const LeftPaneHeader({super.key, this.title = 'Rule Enquiries'});
  final String title;

  static const double _kControlHeight = 40.0; // keep in sync with controls
  static const double _kHorzPad = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return SizedBox(
      height: _kControlHeight,
      child: Row(
        children: [
          // Title (fills available space, vertically centered)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
          ),

          // Controls block (fixed height, vertically centered)
          SizedBox(
            height: _kControlHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoggedIn) ...[
                  NewPostButton(type: PostType.enquiry),
                  const SizedBox(width: 12),
                ],
                FilterDropdown(
                  groups: const [
                    (
                      header: 'General',
                      options: [
                        EnquiryStatusFilter.all(),
                        EnquiryStatusFilter.open(),
                        EnquiryStatusFilter.closedAny(),
                      ],
                    ),
                    (
                      header: 'Closed subsets',
                      options: [
                        EnquiryStatusFilter.closedAmendment(),
                        EnquiryStatusFilter.closedInterpretation(),
                        EnquiryStatusFilter.closedNoResult(),
                      ],
                    ),
                  ],
                  height: _kControlHeight,
                  radius: 8,
                  horizontalPad: _kHorzPad,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// ─────────────────────────────────────────────────────────────────────────
/// LeftPaneNested entry point (unchanged API)
/// ─────────────────────────────────────────────────────────────────────────
class LeftPaneNested extends ConsumerStatefulWidget {
  const LeftPaneNested({super.key, required this.state});
  final GoRouterState state;

  @override
  ConsumerState<LeftPaneNested> createState() => _LeftPaneNestedState();
}

class _LeftPaneNestedState extends ConsumerState<LeftPaneNested> {
  String? get _enquiryId => widget.state.pathParameters['enquiryId'];
  String? get _responseId => widget.state.pathParameters['responseId'];

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 Building left pane');
    // 👇 No more URL-derived filters here
    return _EnquiriesTree(
      initiallyOpenEnquiryId: _enquiryId,
      initiallyOpenResponseId: _responseId,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Enquiries list (applies filters + search)
/// ─────────────────────────────────────────────────────────────────────────

class _EnquiriesTree extends ConsumerWidget {
  const _EnquiriesTree({
    required this.initiallyOpenEnquiryId,
    required this.initiallyOpenResponseId,
  });

  final String? initiallyOpenEnquiryId;
  final String? initiallyOpenResponseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🔍 Building enquiries list');
    final filter = ref.watch(enquiryFilterProvider);
    final itemsAsync = ref.watch(
  combinedEnquiriesProvider((statusFilter: filter.status))
);

// If this is the very first load (no stale data yet), show your full-page loader:
if (itemsAsync.valueOrNull == null) {
  return const Center(
    child: Column(
      children: [
        SizedBox(height: 12),
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Loading enquiries from database...'),
        SizedBox(height: 8),
        Text('(This may take a few seconds to populate)'),
      ],
    ),
  );
}

// From here on, we have stale data available (even if we're reloading)
final isReloading = itemsAsync.isLoading; // true during background refresh
final docs0 = itemsAsync.valueOrNull!;

final rawQ = filter.query.trim().toLowerCase();
List<DocView> docs = docs0;
if (rawQ.isNotEmpty) {
  docs = docs.where((d) {
    final data = d.data();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final numStr = (data['enquiryNumber'] ?? '').toString().toLowerCase();
    return title.contains(rawQ) || numStr.contains(rawQ);
  }).toList();
}

return Stack(
  children: [
    // Your existing list UI (stale-but-usable)
    ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final d = docs[i];
        final id = d.id;
        final data = d.data();
        final title = (data['title'] ?? 'Untitled').toString();
        final n = (data['enquiryNumber'] ?? 'Unnumbered').toString();
        final isOpen = id == initiallyOpenEnquiryId;
        final isPublished = data['isPublished'] ?? false;

        return ExpansionTile(
          key: ValueKey('enq_${id}_$isOpen'),
          initiallyExpanded: isOpen,
          maintainState: false,
          backgroundColor: isOpen
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
              : null,
          onExpansionChanged: (expanded) {
            if (expanded && id != initiallyOpenEnquiryId) {
              TwoPaneScope.of(context)?.closeDrawer();
              Nav.goEnquiry(context, id);
            }
          },
          title: _RowTile(
            label: 'RE #$n - $title',
            selected: isOpen && initiallyOpenResponseId == null,
            showSubtitle: isPublished == false,
            onTap: () {
              TwoPaneScope.of(context)?.closeDrawer();
              Nav.goEnquiry(context, id);
            },
          ),
          children: [
            if (isOpen && isPublished)
              _ResponsesBranch(
                enquiryId: id,
                initiallyOpenResponseId: initiallyOpenResponseId,
              ),
          ],
        );
      },
    ),

    // Subtle top loading bar while fresh data is fetched
    if (isReloading)
      Positioned(
        top: 0, left: 0, right: 0,
        child: const LinearProgressIndicator(),
      ),
  ],
);
  }
}


/// ─────────────────────────────────────────────────────────────────────────
/// Responses for a given enquiry
/// ─────────────────────────────────────────────────────────────────────────
class _ResponsesBranch extends StatelessWidget {
  const _ResponsesBranch({
    required this.enquiryId,
    required this.initiallyOpenResponseId,
  });

  final String enquiryId;
  final String? initiallyOpenResponseId;

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 Building responses list');
    final q = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .where('isPublished', isEqualTo: true)
        .orderBy('roundNumber')
        .orderBy('responseNumber');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          final error = snap.error.toString();
          debugPrint('❌ Firestore query error: $error');
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Failed to load responses'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return leafInfo('No responses yet', context);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0), // add space at the end
          child: Column(
            children: docs.map((d) {
              final id = d.id;
              final data = d.data();
              final label =
                  'Response ${data['roundNumber'] ?? 'x'}.${data['responseNumber'] ?? 'x'}';
              final isOpen = id == initiallyOpenResponseId;

              return Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: ListTile(
                  key: PageStorageKey('resp_${enquiryId}_$id'),
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -3),
                  minVerticalPadding: 0,
                  title: _RowTile(
                    label: label,
                    selected: isOpen,
                    onTap: () {
                      TwoPaneScope.of(context)?.closeDrawer();
                      Nav.goResponse(context, enquiryId, id);
                    },
                  ),
                ),
              );
            }).toList(),
         ),
        );
      },
    );
  }
}


/// ─────────────────────────────────────────────────────────────────────────
/// Row tile shared style
/// ─────────────────────────────────────────────────────────────────────────
class _RowTile extends StatelessWidget {
  const _RowTile({required this.label, this.selected = false, this.showSubtitle = false, this.onTap});
  final String label;
  final bool selected;
  final bool showSubtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3), // tighter
      minVerticalPadding: 0,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: showSubtitle
          ? const Text(
              '(Unpublished)',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            )
          : null,
      onTap: onTap,
      selected: selected,
    );
  }
}


Widget leafInfo(String text, BuildContext context) => Padding(
  padding: const EdgeInsets.only(
    // left: 24, 
    bottom: 8
    ),
  child: Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
    ),
  ),
);