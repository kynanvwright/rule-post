import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../content/widgets/new_post_button.dart';
import '../../riverpod/user_detail.dart';
import 'two_panel_shell.dart';

final filterDefault = 'open';

/// ─────────────────────────────────────────────────────────────────────────
/// Left header: title + status chips + debounced search + "New" button
/// ─────────────────────────────────────────────────────────────────────────
class LeftPaneHeader extends ConsumerStatefulWidget {
  const LeftPaneHeader({
    super.key,
    this.title = "Rule Enquiries",
  });
  final String title;

  @override
  ConsumerState<LeftPaneHeader> createState() => _LeftPaneHeaderState();
}

class _LeftPaneHeaderState extends ConsumerState<LeftPaneHeader> {
  // ---- tweakables (easy to adjust) -----------------------------------------
  static const double _kControlHeight = 40;      // overall height of both
  static const double _kRadius = 8;              // corner radius
  static const double _kHorzPad = 12;            // horizontal padding inside filter
  static const double _kGap = 12;                // space between filter and search
  static const Duration _kDebounce = Duration(milliseconds: 300);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Options
  static const _statusOptions = ['all', 'open', 'closed'];

  String _statusFromUri(BuildContext context) =>
      GoRouterState.of(context).uri.queryParameters['status'] ?? filterDefault;
  String _qFromUri(BuildContext context) =>
      GoRouterState.of(context).uri.queryParameters['q'] ?? '';

  String _statusLabel(String v) => switch (v) {
        'open' => 'Open',
        'closed' => 'Closed',
        _ => 'All',
      };

  IconData _statusIcon(String v) => switch (v) {
        'open' => Icons.lock_open,
        'closed' => Icons.lock,
        _ => Icons.filter_alt,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentStatus = _statusFromUri(context);
      final q = _qFromUri(context);
      if (!['all', 'open', 'closed'].contains(currentStatus)) {
        _updateQuery(context, status: 'open'); // your new default
      }
      _searchCtrl.text = q;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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

  // Measure the longest label in the current text style so the button width is stable.
  double _filterFixedWidth(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14); // fallback if theme is null

    // Find the longest label text.
    final longest = _statusOptions
        .map(_statusLabel)
        .reduce((a, b) => a.length >= b.length ? a : b);

    // Measure text width.
    final tp = TextPainter(
      text: TextSpan(text: longest, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final textW = tp.width;

    // Add space for icons + gaps + padding:
    //  leading icon (20) + gap (6) + trailing arrow (24) + outer padding (left+right)
    const double leadingIcon = 20;
    const double trailingIcon = 24;
    const double innerGap = 6;
    final double paddings = _kHorzPad * 2;

    return textW + leadingIcon + trailingIcon + innerGap + paddings + 8;
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final selectedStatus = _statusFromUri(context);
    final scheme = Theme.of(context).colorScheme;

    final borderColor = scheme.outline; // matches TextField's outline tone
    final onVariant = scheme.onSurfaceVariant;

    // One border style to use for both controls
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: borderColor, width: 1.2),
      borderRadius: BorderRadius.circular(_kRadius),
    );

    final filterWidth = _filterFixedWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (isLoggedIn) NewPostButton(type: PostType.enquiry),
          ],
        ),
        const SizedBox(height: 8),
        // Controls row
        Row(
          children: [
            // Filter (PopupMenu) with fixed width & same visual language as TextField
            SizedBox(
              height: _kControlHeight,
              width: filterWidth,
              child: PopupMenuButton<String>(
                tooltip: 'Filter',
                onSelected: (v) => _updateQuery(context, status: v),
                itemBuilder: (context) => _statusOptions.map((v) {
                  final selected = v == selectedStatus;
                  return PopupMenuItem<String>(
                    value: v,
                    child: Row(
                      children: [
                        Icon(_statusIcon(v), size: 20),
                        const SizedBox(width: 8),
                        Text(_statusLabel(v)),
                        const Spacer(),
                        if (selected) const Icon(Icons.check, size: 18),
                      ],
                    ),
                  );
                }).toList(),
                // Use 'child' to render a custom-styled button matching the TextField
                child: Ink(
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: border, // OutlineInputBorder as ShapeBorder
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: _kHorzPad), // match TF
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(_statusIcon(selectedStatus), color: onVariant, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _statusLabel(selectedStatus),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: onVariant),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: _kGap),
            // Search (TextField) with the same height & border styling
            Expanded(
              child: SizedBox(
                height: _kControlHeight,
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onChanged: (val) {
                    _debounce?.cancel();
                    _debounce = Timer(_kDebounce, () {
                      _updateQuery(context, q: val.trim());
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    isDense: true, // keeps vertical density tight
                    prefixIcon: const Icon(Icons.search),
                    // Make the clear button live inside the field so heights stay identical
                    suffixIcon: (_searchCtrl.text.isNotEmpty)
                        ? IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {}); // refresh suffixIcon visibility
                              _updateQuery(context, q: '');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border.copyWith(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.4,
                      ),
                    ),
                    // Padding tuned to hit the same total height as the filter
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: _kHorzPad, vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
class _EnquiriesTree extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final listQuery = buildEnquiriesQuery(filter);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listQuery.snapshots(),
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

        final docsSnap = snap.data!.docs;
        final rawQ = (filter['q'] ?? '').trim().toLowerCase();

        final docs = rawQ.isEmpty
            ? docsSnap
            : docsSnap.where((d) {
                final data = d.data();
                final title = (data['title'] ?? '').toString().toLowerCase();
                // Optional: also search enquiry number string
                final numStr = (data['enquiryNumber'] ?? '').toString().toLowerCase();
                return title.contains(rawQ) || numStr.contains(rawQ);
              }).toList();


        if (docs.isEmpty) return const Center(child: Text('No matching enquiries'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final id = d.id;
            final data = d.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final selected = id == initiallyOpenEnquiryId;
            final n = (data['enquiryNumber'] ?? 'Unnumbered').toString();

            return ExpansionTile(
              key: PageStorageKey('enq_$id'),
              initiallyExpanded: selected,
              title: _RowTile(
                label: 'RE #$n - $title',
                selected: selected && initiallyOpenResponseId == null,
                onTap: () {
                  TwoPaneScope.of(context)?.closeDrawer();
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
          return leafInfo('No responses yet');
        }

        return Column(
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
                title: _RowTile(
                  label: label,
                  selected: isOpen && initiallySelectedCommentId == null,
                  onTap: () {
                    TwoPaneScope.of(context)?.closeDrawer();
                    context.go('/enquiries/$enquiryId/responses/$id');
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Row tile shared style
/// ─────────────────────────────────────────────────────────────────────────
class _RowTile extends StatelessWidget {
  const _RowTile({required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: onTap,
      selected: selected,
    );
  }
}

Widget leafInfo(String text) => Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
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

  final status = filter['status'] ?? filterDefault; // default filter
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

  // Always keep a stable default order.
  q = q.orderBy('enquiryNumber', descending: true);
  return q;
}

