// flutter_app/lib/core/widgets/filter_dropdown.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../riverpod/enquiry_filter_provider.dart';
import '../models/enquiry_status_filter.dart';

class FilterDropdown extends ConsumerStatefulWidget {
  const FilterDropdown({
    super.key,
    required this.height,
    required this.radius,
    required this.horizontalPad,
  });

  final double height;
  final double radius;
  final double horizontalPad;

  @override
  ConsumerState<FilterDropdown> createState() => FilterDropdownState();
}

class FilterDropdownState extends ConsumerState<FilterDropdown> {
  final _menuController = MenuController();
  late final TextEditingController _localSearchCtrl;

  // Keep the menu compact by default
  bool _showClosedSubfilters = false;

  @override
  void initState() {
    super.initState();
    _localSearchCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncControllerWithProvider(
        ref.read(enquiryFilterProvider).query,
        setSelectionToEnd: true,
      );

      _localSearchCtrl.addListener(() => setState(() {}));
    });
  }

  void _syncControllerWithProvider(
    String query, {
    bool setSelectionToEnd = false,
  }) {
    if (_localSearchCtrl.text != query) {
      final base = TextEditingValue(text: query);
      final sel = setSelectionToEnd
          ? TextSelection.collapsed(offset: query.length)
          : TextSelection.fromPosition(
              TextPosition(offset: query.length),
            );
      _localSearchCtrl.value = base.copyWith(selection: sel);
    }
  }

  @override
  void dispose() {
    _localSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(enquiryFilterProvider);
    final ctrl = ref.read(enquiryFilterProvider.notifier);

    // keep text field synced with provider
    _syncControllerWithProvider(filter.query);

    final scheme = Theme.of(context).colorScheme;
    final onVariant = scheme.onSurfaceVariant;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;
    final overlay = scheme.primary.withValues(alpha: 0.08);

    // The little pill button in the header bar
    final anchor = FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStatePropertyAll(fg),
        overlayColor: WidgetStatePropertyAll(overlay),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: widget.horizontalPad),
        ),
        minimumSize: WidgetStatePropertyAll(Size(0, widget.height)),
      ),
      onPressed: () => _menuController.isOpen ? _menuController.close() : _menuController.open(),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.filter_alt, size: 20)],
      ),
    );

    // Popup content
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
              // ── Title Row / Close button ──────────────────────────────
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

              // ── STATUS SECTION ────────────────────────────────────────
              //
              // One RadioGroup<EnquiryStatusFilter> for everything, so we
              // don't have deprecated groupValue/onChanged on each tile.
              RadioGroup<EnquiryStatusFilter>(
                groupValue: filter.status,
                onChanged: (val) {
                  if (val == null) return;
                  ctrl.setStatus(val);
                  setState(() {}); // reflect new tick immediately
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subheader
                    Row(
                      children: [
                        Icon(Icons.filter_list, size: 18, color: onVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // All
                    RadioListTile<EnquiryStatusFilter>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: const EnquiryStatusFilter.all(),
                      title: Row(
                        children: const [
                          Icon(Icons.filter_alt, size: 18),
                          SizedBox(width: 8),
                          Text('All'),
                        ],
                      ),
                    ),

                    // Open
                    RadioListTile<EnquiryStatusFilter>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: const EnquiryStatusFilter.open(),
                      title: Row(
                        children: const [
                          Icon(Icons.lock_open, size: 18),
                          SizedBox(width: 8),
                          Text('Open'),
                        ],
                      ),
                    ),

                    // Closed (any)
                    RadioListTile<EnquiryStatusFilter>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: const EnquiryStatusFilter.closedAny(),
                      title: Row(
                        children: const [
                          Icon(Icons.lock, size: 18),
                          SizedBox(width: 8),
                          Text('Closed'),
                        ],
                      ),
                    ),

                    // Toggle to reveal closed subtypes
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _showClosedSubfilters = !_showClosedSubfilters;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showClosedSubfilters
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: onVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'More closed filters…',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: onVariant),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Conditionally show subfilters, indented
                    if (_showClosedSubfilters) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0),
                        child: Column(
                          children: [
                            RadioListTile<EnquiryStatusFilter>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: const EnquiryStatusFilter.closedAmendment(),
                              title: Row(
                                children: const [
                                  Icon(Icons.edit_document, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(child: Text('Amendment')),
                                ],
                              ),
                            ),
                            RadioListTile<EnquiryStatusFilter>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: const EnquiryStatusFilter.closedInterpretation(),
                              title: Row(
                                children: const [
                                  Icon(Icons.menu_book, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(child: Text('Interpretation')),
                                ],
                              ),
                            ),
                            RadioListTile<EnquiryStatusFilter>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: const EnquiryStatusFilter.closedNoResult(),
                              title: Row(
                                children: const [
                                  Icon(Icons.do_not_disturb_alt, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(child: Text('No Result')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 20),
                  ],
                ),
              ),

              // ── SEARCH SECTION ────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.search, size: 18, color: onVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Search',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _localSearchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: ctrl.setQuery,
                onSubmitted: ctrl.setQuery,
                decoration: InputDecoration(
                  hintText: 'Type to search…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _localSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _localSearchCtrl.clear();
                            ctrl.clearQuery();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── FOOTER ROW ───────────────────────────────────────────
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ctrl.reset(
                        defaultStatus: const EnquiryStatusFilter.all(),
                      );
                      _localSearchCtrl.clear();
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

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 8),
      menuChildren: [IntrinsicWidth(child: menuCard)],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(widget.radius),
          child: anchor,
        );
      },
    );
  }
}
