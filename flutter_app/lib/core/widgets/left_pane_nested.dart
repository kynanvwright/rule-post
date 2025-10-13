import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../content/widgets/new_post_button.dart';
import '../../riverpod/user_detail.dart';
import '../widgets/draft_viewing.dart';
import 'two_panel_shell.dart';
import 'navigator_helper.dart';

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
                _ControlsDropdown(
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
    context.go(Uri(path: s.path, queryParameters: params).toString());
  }
}


class _ControlsDropdown extends StatefulWidget {
  const _ControlsDropdown({
    required this.selectedStatus,
    required this.statusOptions,
    required this.statusIcon,
    required this.statusLabel,
    required this.initialQuery,
    required this.onStatusChanged,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.height,
    required this.radius,
    required this.horizontalPad,
  });

  final String selectedStatus;
  final List<String> statusOptions;
  final IconData Function(String) statusIcon;
  final String Function(String) statusLabel;

  final String initialQuery;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;

  final double height;
  final double radius;
  final double horizontalPad;

  @override
  State<_ControlsDropdown> createState() => _ControlsDropdownState();
}

class _ControlsDropdownState extends State<_ControlsDropdown> {
  final _menuController = MenuController();
  late final TextEditingController _localSearchCtrl;

  @override
  void initState() {
    super.initState();
    _localSearchCtrl = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _localSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Anchor button styled like your NewPostButton
    final scheme = Theme.of(context).colorScheme;
    final onVariant = scheme.onSurfaceVariant;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;
    final overlay = scheme.primary.withValues(alpha: 0.08);

    final anchor = FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStatePropertyAll(fg),
        overlayColor: WidgetStatePropertyAll(overlay),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: widget.horizontalPad),
        ),
        minimumSize: WidgetStatePropertyAll(
          Size(0, widget.height),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.filter_alt, size: 20),
        ],
      ),
      onPressed: () {
        _menuController.isOpen
            ? _menuController.close()
            : _menuController.open();
      },
    );

    // The dropdown content (card with filter + search)
    final menuCard = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row shows icons as “legend”
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 18, color: onVariant),
                  const SizedBox(width: 6),
                  Text('Filter', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _menuController.close(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Status filter as radio list
              ...widget.statusOptions.map((opt) {
                final selected = opt == widget.selectedStatus;
                return RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: opt,
                  groupValue: widget.selectedStatus,
                  onChanged: (v) {
                    if (v == null) return;
                    widget.onStatusChanged(v);
                    setState(() {}); // just to reflect selection instantly
                  },
                  title: Row(
                    children: [
                      Icon(widget.statusIcon(opt), size: 18),
                      const SizedBox(width: 8),
                      Text(widget.statusLabel(opt)),
                      if (selected) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 16),
                      ],
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              // Search section
              Row(
                children: [
                  Icon(Icons.search, size: 18, color: onVariant),
                  const SizedBox(width: 6),
                  Text('Search', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _localSearchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (val) => widget.onQueryChanged(val),
                onSubmitted: (val) => widget.onQueryChanged(val),
                decoration: InputDecoration(
                  hintText: 'Type to search…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _localSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _localSearchCtrl.clear();
                            widget.onClearQuery();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              // Footer actions
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // Reset to defaults
                      widget.onStatusChanged('all');
                      _localSearchCtrl.clear();
                      widget.onClearQuery();
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _menuController.close(),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Use MenuAnchor when available (Flutter Material 3). It keeps the menu open while interacting.
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        // Wrap in IntrinsicWidth so the card sizes to content
        IntrinsicWidth(child: menuCard),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            controller.isOpen ? controller.close() : controller.open();
          },
          borderRadius: BorderRadius.circular(widget.radius),
          child: anchor,
        );
      },
    );
  }
}



/// ─────────────────────────────────────────────────────────────────────────
/// LeftPaneNested entry point (unchanged API)
/// ─────────────────────────────────────────────────────────────────────────
class LeftPaneNested extends StatefulWidget {
  const LeftPaneNested({super.key, required this.state});
  final GoRouterState state;

  @override
  State<LeftPaneNested> createState() => _LeftPaneNestedState();
}

class _LeftPaneNestedState extends State<LeftPaneNested> {
  String? get _enquiryId => widget.state.pathParameters['enquiryId'];
  String? get _responseId => widget.state.pathParameters['responseId'];
  String? get _commentId => widget.state.pathParameters['commentId'];

  @override
  Widget build(BuildContext context) {
    final qp = widget.state.uri.queryParameters; // status + q live here
    return _EnquiriesTree(
      initiallyOpenEnquiryId: _enquiryId,
      initiallyOpenResponseId: _responseId,
      initiallySelectedCommentId: _commentId,
      filter: qp,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Enquiries list (applies filters + search)
/// ─────────────────────────────────────────────────────────────────────────
final openIndexProvider = StateProvider<int?>((ref) => null);
/// 
class _EnquiriesTree extends ConsumerWidget {
  const _EnquiriesTree({
    required this.initiallyOpenEnquiryId,
    required this.initiallyOpenResponseId,
    required this.initiallySelectedCommentId,
    required this.filter,
  });

  final String? initiallyOpenEnquiryId;
  final String? initiallyOpenResponseId;
  final String? initiallySelectedCommentId;
  final Map<String, String> filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(teamProvider);
    final rawQ = (filter['q'] ?? '').trim().toLowerCase();

    return StreamBuilder<List<DocView>>(
      stream: combinedEnquiriesStream(teamId: teamId, filter: filter),
      builder: (context, snap) {
        if (snap.hasError) {
          final error = snap.error.toString();
          debugPrint('❌ Firestore query error: $error');

          // Extract index creation link if present.
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

        // route-controlled accordion: only one open at once, synced to enquiryId in the URL
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final id = d.id;
            final data = d.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final n = (data['enquiryNumber'] ?? 'Unnumbered').toString();

            // 👇 route-driven open state
            final routeEnquiryId = initiallyOpenEnquiryId; // passed from GoRouterState
            final isOpen = id == routeEnquiryId;

            return ExpansionTile(
              // 👇 include isOpen in the key so internal state follows the route
              key: ValueKey('enq_${id}_$isOpen'),
              initiallyExpanded: isOpen,
              maintainState: false, // don't keep children alive when not routed
              backgroundColor: isOpen
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : null,

              // 👇 user toggles cause navigation, not local state changes
              onExpansionChanged: (expanded) {
                if (expanded && id != routeEnquiryId) {
                  // Open another enquiry -> navigate to that enquiry
                  TwoPaneScope.of(context)?.closeDrawer();
                  goWithQuery(context,'/enquiries/$id');
                } else if (!expanded && id == routeEnquiryId) {
                  // Collapsing the routed enquiry: choose one behaviour:
                  // A) keep it open by snapping back (do nothing; the key+initiallyExpanded will reopen)
                  // or B) navigate to a route without enquiry to truly collapse:
                  // context.go('/enquiries'); // <- uncomment if you want collapse via route
                }
              },

              title: _RowTile(
                label: 'RE #$n - $title',
                selected: isOpen && initiallyOpenResponseId == null, // highlight follows route
                showSubtitle: data['isPublished'] == false,
                onTap: () {
                  // Always let the route drive UI
                  TwoPaneScope.of(context)?.closeDrawer();
                  goWithQuery(context,'/enquiries/$id');
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
                      goWithQuery(context, '/enquiries/$enquiryId/responses/$id');
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
  padding: const EdgeInsets.only(left: 24, bottom: 8),
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



