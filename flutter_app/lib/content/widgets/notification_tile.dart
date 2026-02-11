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
  String? _scopeOverride;

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

    // Clear scope override once provider reflects the value
    ref.listen<String>(emailNotificationsScopeProvider, (prev, curr) {
      if (_scopeOverride != null && curr == _scopeOverride) {
        if (!mounted) return;
        setState(() {
          _scopeOverride = null;
        });
      }
    });

    final current = ref.watch(emailNotificationsOnProvider);
    final currentScope = ref.watch(emailNotificationsScopeProvider);
    final displayValue = _override ?? current;
    final displayScope = _scopeOverride ?? currentScope;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          title: const Text('Email notifications'),
          subtitle: const Text('Receive updates on new activity'),
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
        ),

        // Scope chooser (only when notifications are enabled)
        if (displayValue) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receive notifications for:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final newScope = displayScope == 'all' ? 'enquiries' : 'all';
                    setState(() => _scopeOverride = newScope);
                    try {
                      await setEmailNotificationScope(newScope);
                      await forceRefreshClaims();
                      ref.invalidate(allClaimsProvider);
                    } catch (e, st) {
                      d('setEmailNotificationScope failed: $e\n$st');
                      if (!mounted) return;
                      setState(() => _scopeOverride = null);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All activity (enquiries, responses, comments)',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: displayScope == 'all' 
                            ? Theme.of(context).textTheme.bodyMedium?.color 
                            : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48,
                        height: 28,
                        decoration: BoxDecoration(
                          color: displayScope == 'all' 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey[300],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              alignment: displayScope == 'all' ? Alignment.centerLeft : Alignment.centerRight,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'New enquiries only',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: displayScope == 'enquiries' 
                            ? Theme.of(context).textTheme.bodyMedium?.color 
                            : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

