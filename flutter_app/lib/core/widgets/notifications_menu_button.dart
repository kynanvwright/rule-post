// flutter_app/lib/core/widgets/notifications_menu_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../riverpod/unread_post_provider.dart';
import '../../navigation/nav.dart';
import 'delete_button.dart';


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
    final count = ref.watch(unreadStrictCountProvider);
    final hostContext = context;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return SizedBox();

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
        menuChildren: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8,8,8,4),
            child: Center(
              child: Text(
                'Unread Posts',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8,4,8,8),
            child: Center( 
              child: DeleteButton(
                labelText: 'Mark all as read',
                icon: Icons.mark_email_read_outlined,
                tooltipText: '',
                onConfirmDelete: () async {
                  final collectionRef = FirebaseFirestore.instance
                      .collection('user_data')
                      .doc(uid)
                      .collection('unreadPosts');
                  final snap = await collectionRef.get();
                  for (final doc in snap.docs) {
                    await doc.reference.delete();
                  }
                },
              ),
            ),
          ),
          const Divider(height: 1),
          UnreadMenu(
            onSelect: (enquiryId, [responseId]) {
              Nav.goToPost(hostContext, enquiryId, responseId);
            },
          ),
        ],
      ),
      
    );
  }
}


class UnreadMenu extends ConsumerWidget {
  const UnreadMenu({
    super.key,
    required this.onSelect,
    this.maxHeight = 360,
    this.maxWidth = 260,
    this.groupByType = true,
  });

  final void Function(String enquiryId, [String? responseId]) onSelect;
  final double maxHeight;
  final double maxWidth;
  final bool groupByType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(unreadPostsStreamProvider);

    Widget scrollableMenu(List<Widget> children, {double? maxWidth, double? maxHeight}) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 400,
          maxHeight: maxHeight ?? 360,
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: IntrinsicWidth( // makes width wrap content up to maxWidth
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      );
    }

    return itemsAsync.when<Widget>(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, st) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text('Failed to load: $err', maxLines: 2, overflow: TextOverflow.ellipsis),
          dense: true,
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('No items'),
              dense: true,
            ),
          );
        }

        final orderedKeys = generateOrderedKeys(items);
        final children = <Widget>[];

        for (final orderedKey in orderedKeys) {

          final postData = items[orderedKey];
          final alias = postData?['postAlias'] ?? '';
          final isUnread = postData?['isUnread'] == true;
          final isClickable = (postData?['isUnread'] == true) || (postData?['postType'] == 'response');
          String menuText;
          VoidCallback? onTapNavigation;

          if (postData?['postType'] == 'enquiry') {
            if (isUnread) {
                menuText = alias;
                onTapNavigation = () => onSelect(orderedKey, );
            } else {
                menuText = '$alias:';
              }
          } else if (postData?['postType'] == 'response') {
            if (isUnread) {
                menuText = '  $alias';
            } else {
              final childrenCount = items.values
                .where((e) => e['postType'] == 'comment' && e['parentId'] == orderedKey)
                .length;
                menuText = childrenCount == 0 ?
                  '  $alias' : childrenCount == 1 ?
                  '  $alias ($childrenCount new comment)' :
                  '  $alias ($childrenCount new comments)';              
            }
            onTapNavigation = () => onSelect(postData?['parentId'], orderedKey);
          } else {
            continue;
          }

          children.add(
            MenuItemButton(
              onPressed: isClickable ? onTapNavigation : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      menuText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (children.isEmpty) {
          // In case all enquiries were filtered out somehow
          return const Padding(
            padding: EdgeInsets.all(12),
            child: ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('No items'),
              dense: true,
            ),
          );
        }

        return Material(type: MaterialType.transparency, child: scrollableMenu(children));
      },
    );
  }
}


extension SafeGet on Map<String, dynamic> {
  String s(String key, [String def = '']) {
    final v = this[key];
    if (v == null) return def;
    return v is String ? v : v.toString();
  }

  int i(String key, [int def = 1 << 30]) {
    final v = this[key];

    if (v is int) return v;
    if (v is num) return v.toInt();

    if (v is String) {
      // Normalise: trim, convert Unicode minus to ASCII, strip thousands commas
      final t = v
          .trim()
          .replaceAll('\u2212', '-')   // Unicode minus → '-'
          .replaceAll('\u2013', '-')   // en dash just in case
          .replaceAll(',', '');        // remove separators if any

      // Only accept clean integers
      final m = RegExp(r'^[+-]?\d+$').firstMatch(t);
      if (m != null) return int.parse(t);
    }

    return def; // big number -> sorts to end
  }
}


/// Extracts the enquiry number from "RE #{enquiryNumber} - {title}".
/// Accepts optional whitespace and sign; normalises Unicode minus.
int? extractEnquiryNumberFromAlias(String alias) {
  final norm = alias
      .trim()
      .replaceAll('\u2212', '-')  // Unicode minus → ASCII
      .replaceAll('\u2013', '-'); // en dash → ASCII

  final re = RegExp(r'^RE\s*#\s*([+-]?\d+)\s*-', caseSensitive: false);
  final m = re.firstMatch(norm);
  return m == null ? null : int.tryParse(m.group(1)!);
}


List<String> generateOrderedKeys(Map<String, Map<String, dynamic>> items) {
  final ordered = <String>[];
  final all = items.entries.toList();

  // Enquiries first (missing/ill-typed fields handled via helpers)
  final enquiries = all
      .where((e) => e.value.s('postType') == 'enquiry')
      .toList()
    ..sort((a, b) {
      final an = extractEnquiryNumberFromAlias(a.value.s('postAlias'))
          ?? a.value.i('enquiryNumber', 1 << 30); // fallback if alias is malformed
      final bn = extractEnquiryNumberFromAlias(b.value.s('postAlias'))
          ?? b.value.i('enquiryNumber', 1 << 30);

    final c = an.compareTo(bn);
    // multiply by -1 for descending sort
    return (-1) * (c != 0 ? c : a.key.compareTo(b.key));
    });

  for (final enquiry in enquiries) {
    ordered.add(enquiry.key);

    if (enquiry.value['isUnread'] == false || enquiry.value['isUnread'] == null) {
      // Children responses under each enquiry
      final responses = all
          .where((e) =>
              e.value.s('postType') == 'response' &&
              e.value.s('parentId') == enquiry.key)
          .toList()
        ..sort((a, b) {
          final c = a.value.s('postAlias').compareTo(b.value.s('postAlias'));
          return c != 0 ? c : a.key.compareTo(b.key);
        });

      for (final response in responses) {
        ordered.add(response.key);
      }
    }
  }

  return ordered;
}