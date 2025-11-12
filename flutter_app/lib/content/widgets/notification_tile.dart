//content/widgets/notification_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/api/notification_api.dart';
import 'package:rule_post/riverpod/user_detail.dart';

class EmailNotificationsTile extends ConsumerStatefulWidget {
  const EmailNotificationsTile({super.key});

  @override
  ConsumerState<EmailNotificationsTile> createState() =>
      _EmailNotificationsTileState();
}

class _EmailNotificationsTileState
    extends ConsumerState<EmailNotificationsTile> {
  bool? _optimistic; // while non-null, overrides provider
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(emailNotificationsOnProvider, (prev, curr) {
      if (_optimistic != null && curr == _optimistic) {
        if (mounted) {
          setState(() {
            _optimistic = null;
            _busy = false;
          });
        }
      }
    });
    final current = ref.watch(emailNotificationsOnProvider);
    final displayValue = _optimistic ?? current;

    return SwitchListTile.adaptive(
      title: const Text('Email notifications'),
      subtitle: const Text(
        'Receive updates on new enquiries, responses and comments',
      ),
      value: displayValue,
      onChanged: _busy
          ? null
          : (next) async {
              debugPrint('[EmailNotificationsTile] toggle -> $next');
              setState(() {
                _busy = true;
                _optimistic = next; // optimistic UI
              });
              try {
                await toggleEmailNotifications(next);
                ref.invalidate(allClaimsProvider);
              } catch (e) {
                setState(() {
                  _optimistic = null;
                  _busy = false;
                });
              }
            },
      secondary: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
