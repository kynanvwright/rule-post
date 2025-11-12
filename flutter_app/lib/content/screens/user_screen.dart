// flutter_app/lib/content/screens/user_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/auth/widgets/team_admin_panel.dart';
import 'package:rule_post/content/widgets/notification_tile.dart';
import 'package:rule_post/core/models/types.dart' show ClaimSpec;
import 'package:rule_post/core/widgets/back_button.dart';
import 'package:rule_post/riverpod/user_detail.dart';


class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key});
  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen> {

  // ✅ Only show these claim keys if present (edit to taste)
  static const List<ClaimSpec> _shownClaimSpecs = [
    ClaimSpec(key: 'email', label: 'Email', icon: Icons.email),
    ClaimSpec(key: 'role', label: 'Role', icon: Icons.verified_user),
    ClaimSpec(key: 'team', label: 'Team', icon: Icons.flag),
  ];

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(allClaimsProvider);
    final isTeamAdmin = ref.watch(isTeamAdminProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: BackButtonCompact(),
        ),
        title: const Text('Profile'),
    ),
      body: claimsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (claims) {

          // Build tiles only for claims that exist
          final infoTiles = _shownClaimSpecs
              .where((spec) => claims.containsKey(spec.key))
              .map((spec) {
            final value = claims[spec.key];
            return ListTile(
              leading: Icon(spec.icon),
              title: Text('${spec.label}: ${_formatValue(value)}'),
              dense: true,
              visualDensity: VisualDensity.compact,
            );
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== User Information =====
              Text('User Information',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (infoTiles.isEmpty)
                Card(
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('No visible user info'),
                    subtitle: Text(
                      'Your account has no matching custom claims from the shown subset.',
                    ),
                    dense: true,
                  ),
                )
              else
                Card(
                  child: Column(children: infoTiles),
                ),

              const SizedBox(height: 24),

              // ===== Settings =====
              Text('Settings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(child: EmailNotificationsTile()),
              const SizedBox(height: 24),

              // ===== Team Admin panel =====
              if (isTeamAdmin)...[
              Text('Team Admin Panel', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(child: TeamAdminPanel()),
              const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _formatValue(dynamic v) {
    if (v == null) return '(none)';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    // Fall back to compact JSON for objects/arrays
    return const JsonEncoder.withIndent('  ').convert(v);
  }
}