import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../riverpod/enquiry_filter_provider.dart';

class FilterDropdown extends ConsumerStatefulWidget {
  const FilterDropdown({
    super.key,
    required this.statusOptions,
    required this.statusIcon,
    required this.statusLabel,
    required this.height,
    required this.radius,
    required this.horizontalPad,
  });

  final List<String> statusOptions;
  final IconData Function(String) statusIcon;
  final String Function(String) statusLabel;

  final double height;
  final double radius;
  final double horizontalPad;

  @override
  ConsumerState<FilterDropdown> createState() => FilterDropdownState();
}

class FilterDropdownState extends ConsumerState<FilterDropdown> {
  final _menuController = MenuController();
  late final TextEditingController _localSearchCtrl;

  @override
  void initState() {
    super.initState();
    _localSearchCtrl = TextEditingController();

    // One-time hydration from widget props if provider is at defaults.
    WidgetsBinding.instance.addPostFrameCallback((_) {

      // Sync controller to provider
      _syncControllerWithProvider(ref.read(enquiryFilterProvider).query, setSelectionToEnd: true);

      // Rebuild suffix icon visibility as user types
      _localSearchCtrl.addListener(() => setState(() {}));
    });
  }

  void _syncControllerWithProvider(String query, {bool setSelectionToEnd = false}) {
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

    // Keep text field in sync if provider changed externally
    _syncControllerWithProvider(filter.query);

    // Anchor styling
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
        minimumSize: WidgetStatePropertyAll(Size(0, widget.height)),
      ),
      onPressed: () => _menuController.isOpen ? _menuController.close() : _menuController.open(),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.filter_alt, size: 20)],
      ),
    );

    // Card content
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

              // Status list (driven by provider)
              ...widget.statusOptions.map((opt) {
                final selected = opt == filter.status;
                // Wrap your radio tiles in a RadioGroup<String>
                return RadioGroup<String>(
                  groupValue: filter.status,               // <-- moved here
                  onChanged: (String? v) {                 // <-- moved here
                    if (v == null) return;
                    ctrl.setStatus(v);
                    setState(() {}); // instant visual checkmark
                  },
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: opt,
                    selected: opt == filter.status,
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
                  ),
                );
              }),
              const Divider(height: 20),

              // Search row
              Row(
                children: [
                  Icon(Icons.search, size: 18, color: onVariant),
                  const SizedBox(width: 6),
                  Text('Search', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),

              // Search input (provider-backed)
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),

              // Footer
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ctrl.reset(defaultStatus: 'all');
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
