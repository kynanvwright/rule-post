//content/widgets/notification_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/user_detail.dart';

class EmailNotificationsTile extends ConsumerStatefulWidget {
  const EmailNotificationsTile({super.key});
  @override
  ConsumerState<EmailNotificationsTile> createState() => _EmailNotificationsTileState();
}

class _EmailNotificationsTileState extends ConsumerState<EmailNotificationsTile> {
  bool? _optimistic; // null => follow provider
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(emailNotificationsOnProvider);
    final value = _optimistic ?? current;

    return SwitchListTile.adaptive(
      title: const Text('Email notifications'),
      value: value,
      onChanged: _busy
          ? null
          : (next) async {
              debugPrint('[EmailNotificationsTile] toggle -> $next');
              setState(() {
                _busy = true;
                _optimistic = next; // optimistic UI
              });

              try {
                final setFn = ref.read(setEmailNotifications);
                await setFn(next);

                // On success, return to provider-driven state
                if (mounted) {
                  setState(() {
                    _optimistic = null;
                    _busy = false;
                  });
                }
              } catch (e, st) {
                debugPrint('[EmailNotificationsTile] error: $e\n$st');
                if (mounted) {
                  setState(() {
                    _optimistic = null; // revert to provider value
                    _busy = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update: $e')),
                  );
                }
              }
            },
      secondary: _busy
          ? const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }
}
