// flutter_app/lib/core/widgets/unread_dot.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/riverpod/unread_post_provider.dart';


class UnreadDot extends ConsumerWidget {
  const UnreadDot(this.enquiryId, {this.expanded = false, super.key});
  final String enquiryId;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadByIdProvider(enquiryId));

    final showDot = 
      (unreadAsync?['isUnread'] == true) ||
      ((unreadAsync?['hasUnreadChild'] == true) && !expanded);

    return AnimatedOpacity(
      opacity: showDot ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(
          Icons.circle,
          size: 8,
          // color: Colors.blueAccent,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}