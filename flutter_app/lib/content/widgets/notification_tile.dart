// flutter_app/lib/content/widgets/notification_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/api/notification_api.dart';
import 'package:rule_post/debug/debug.dart';
import 'package:rule_post/riverpod/user_detail.dart';


// Allows email notifications to be toggled on/off
class EmailNotificationsTile extends ConsumerStatefulWidget {
  const EmailNotificationsTile({super.key});

  @override
  ConsumerState<EmailNotificationsTile> createState() =>
      _EmailNotificationsTileState();
}

class _EmailNotificationsTileState extends ConsumerState<EmailNotificationsTile> {
  bool _busy = false;

  bool? _override;   // what we show immediately after the call returns

  @override
  Widget build(BuildContext context) {
    // Clear override once provider reflects the value
    ref.listen<bool>(emailNotificationsOnProvider, (prev, curr) {
      if (_override != null && curr == _override) {
        if (!mounted) return;
        setState(() {
          _override = null;
        });
      }
    });

    final current = ref.watch(emailNotificationsOnProvider);
    final displayValue = _override ?? current;

    return SwitchListTile.adaptive(
      title: const Text('Email notifications'),
      subtitle: const Text('Receive updates on new enquiries, responses and comments'),
      value: displayValue,
      onChanged: _busy
          ? null
          : (next) async {
              setState(() {
                _busy = true;
              });

              try {
                // Use backend return as immediate truth
                final confirmed = await toggleEmailNotifications(next);

                if (!mounted) return;
                setState(() {
                  _override = confirmed; // optimistic based on server-confirmed value
                  _busy = false;
                });

                // Kick claims refresh in the background-ish (no UI blocking)
                await forceRefreshClaims();
                ref.invalidate(allClaimsProvider);

              } catch (e, st) {
                d('toggleEmailNotifications failed: $e\n$st');
                if (!mounted) return;
                setState(() {
                  _busy = false;
                  _override = null;
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
