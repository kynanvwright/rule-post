import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../content/widgets/new_post_button.dart';
import '../../riverpod/user_detail.dart';
import '../../riverpod/enquiry_filter_provider.dart';
import '../widgets/draft_viewing.dart';
import 'two_panel_shell.dart';
// import 'navigator_helper.dart';
import 'filter_dropdown.dart';

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
                  selectedStatus: GoRouterState.of(context)
                      .uri
                      .queryParameters['status'] ?? 'all',
                  statusOptions: const ['all', 'open', 'closed'],
                  statusIcon: (v) => switch (v) {
                    'open' => Icons.lock_open,
                    'closed' => Icons.lock,
                    _ => Icons.filter_alt,
                  },
                  statusLabel: (v) => switch (v) {
                    'open' => 'Open',
                    'closed' => 'Closed',
                    _ => 'All',
                  },
                  initialQuery: GoRouterState.of(context)
                      .uri
                      .queryParameters['q'] ?? '',
                  onStatusChanged: (v) => _updateQuery(context, status: v),
                  onQueryChanged: (val) =>
                      _updateQuery(context, q: val.trim()),
                  onClearQuery: () => _updateQuery(context, q: ''),
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

  void _updateQuery(BuildContext context, {String? status, String? q}) {
    final s = GoRouterState.of(context).uri;
    final params = Map<String, String>.from(s.queryParameters);
    if (status != null) params['status'] = status;
    if (q != null) {
      if (q.isEmpty) {
        params.remove('q');
      } else {
        params['q'] = q;
      }
    }
    context.push(Uri(path: s.path, queryParameters: params).toString());
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
  String? get _commentId => widget.state.pathParameters['commentId'];

  @override
  Widget build(BuildContext context) {
    // 👇 No more URL-derived filters here
    return _EnquiriesTree(
      initiallyOpenEnquiryId: _enquiryId,
      initiallyOpenResponseId: _responseId,
      initiallySelectedCommentId: _commentId,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Enquiries list (applies filters + search)
/// ─────────────────────────────────────────────────────────────────────────
final openIndexProvider = StateProvider<int?>((ref) => null);

class _EnquiriesTree extends ConsumerWidget {
  const _EnquiriesTree({
    required this.initiallyOpenEnquiryId,
    required this.initiallyOpenResponseId,
    required this.initiallySelectedCommentId,
  });

  final String? initiallyOpenEnquiryId;
  final String? initiallyOpenResponseId;
  final String? initiallySelectedCommentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(teamProvider);
    final filter = ref.watch(enquiryFilterProvider);       // 👈 provider source of truth
    final rawQ = filter.query.trim().toLowerCase();          // client-side search string

    // If your stream only needs server-side status, keep it small:
    final serverFilter = <String, String>{
      'status': filter.status, // e.g. 'all' | 'open' | 'closed'
      // Don't send 'q' to Firestore if you only filter by text client-side
    };

    return StreamBuilder<List<DocView>>(
      stream: combinedEnquiriesStream(teamId: teamId, filter: serverFilter),
      builder: (context, snap) {
        if (snap.hasError) {
          final error = snap.error.toString();
          debugPrint('❌ Firestore query error: $error');
          final link = RegExp(r'https://console\.firebase\.google\.com[^\s\)]*')
              .firstMatch(error)
              ?.group(0);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Failed to load enquiries'),
                const SizedBox(height: 8),
                if (link != null)
                  TextButton(
                    onPressed: () => launchUrlString(link),
                    child: const Text('Create required Firestore index'),
                  ),
              ],
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // keep your client-side search
        List<DocView> docs = snap.data!;
        if (rawQ.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final title = (data['title'] ?? '').toString().toLowerCase();
            final numStr = (data['enquiryNumber'] ?? '').toString().toLowerCase();
            return title.contains(rawQ) || numStr.contains(rawQ);
          }).toList();
        }

        final routeEnquiryId = initiallyOpenEnquiryId;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final id = d.id;
            final data = d.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final n = (data['enquiryNumber'] ?? 'Unnumbered').toString();

            final isOpen = id == routeEnquiryId;

            return ExpansionTile(
              key: ValueKey('enq_${id}_$isOpen'),
              initiallyExpanded: isOpen,
              maintainState: false,
              backgroundColor: isOpen
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : null,

              onExpansionChanged: (expanded) {
                if (expanded && id != routeEnquiryId) {
                  TwoPaneScope.of(context)?.closeDrawer();
                  // 👇 IMPORTANT: do NOT append query now—filters are provider-based
                  context.go('/enquiries/$id');
                } else if (!expanded && id == routeEnquiryId) {
                  // (Optional) collapse by routing to list
                  // context.go('/enquiries');
                }
              },

              title: _RowTile(
                label: 'RE #$n - $title',
                selected: isOpen && initiallyOpenResponseId == null,
                showSubtitle: data['isPublished'] == false,
                onTap: () {
                  TwoPaneScope.of(context)?.closeDrawer();
                  // 👇 Same—no querystring
                  context.go('/enquiries/$id');
                },
              ),

              children: [
                _ResponsesBranch(
                  enquiryId: id,
                  initiallyOpenResponseId: initiallyOpenResponseId,
                  initiallySelectedCommentId: initiallySelectedCommentId,
                ),
              ],
            );
          },
        );
      },
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
    required this.initiallySelectedCommentId,
  });

  final String enquiryId;
  final String? initiallyOpenResponseId;
  final String? initiallySelectedCommentId;

  @override
  Widget build(BuildContext context) {
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
                    selected: isOpen && initiallySelectedCommentId == null,
                    onTap: () {
                      TwoPaneScope.of(context)?.closeDrawer();
                      // goWithQuery(context, '/enquiries/$enquiryId/responses/$id');
                      context.push('/enquiries/$enquiryId/responses/$id');
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


/// ─────────────────────────────────────────────────────────────────────────
/// Query builder: isOpen filter + search (prefix on title_lc)
/// Ensure you write `title_lc` (lowercased) at create/update time.
/// ─────────────────────────────────────────────────────────────────────────
Query<Map<String, dynamic>> buildEnquiriesQuery(Map<String, String> filter) {
  var q = FirebaseFirestore.instance
      .collection('enquiries')
      .where('isPublished', isEqualTo: true)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (s, _) => s.data() ?? {},
        toFirestore: (v, _) => v,
      );

  final status = filter['status'] ?? filterDefault;

  switch (status) {
    case 'open':
      q = q.where('isOpen', isEqualTo: true);
      break;
    case 'closed':
      q = q.where('isOpen', isEqualTo: false);
      break;
    default:
      break;
  }

  q = q.orderBy('enquiryNumber', descending: true);
  return q;
}



