// flutter_app/lib/core/widgets/notifications_menu_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/unread_post_provider.dart';

class NotificationsMenuButton extends ConsumerWidget {
  const NotificationsMenuButton({
    super.key,
    this.icon = Icons.notifications_outlined,
    this.tooltip = 'Unread posts',
    this.iconSize = 24,
    this.minTap = 32,
    this.onItemSelected, // optional callback
  });

  final IconData icon;
  final String tooltip;
  final double iconSize;
  final double minTap;
  final void Function(String value)? onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final count = ref.watch(unreadSingleCountProvider);
    final itemsAsync = ref.watch(unreadPostsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      child: MenuAnchor(
        builder: (context, controller, _) {
          return IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            splashRadius: (iconSize + minTap) / 4,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: Badge(
              // If you don't have Material's Badge, replace with a Stack+Positioned (shown below).
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: Icon(icon, color: scheme.onPrimary, size: iconSize),
            ),
          );
        },
        menuChildren: itemsAsync.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          error: (err, st) => [
            MenuItemButton(
              leadingIcon: const Icon(Icons.error_outline),
              onPressed: null,
              child: const Text('Failed to load'),
            ),
          ],
          data: (items) => items.isEmpty
              ? const [
                  MenuItemButton(
                    // leadingIcon: Icon(Icons.inbox_outlined),
                    onPressed: null,
                    child: Text('No items'),
                  ),
                ]
              : [
                  for (final v in items.entries)
                    MenuItemButton(
                      // leadingIcon: const Icon(Icons.circle),
                      child: Text(v.key),
                      onPressed: () => onItemSelected?.call(v.key),
                    ),
                ],
        ),
      ),
    );
  }
}
