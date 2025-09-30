//content/screens/user_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/user_detail.dart';
import '../../api/create_user_api.dart';
import '../../auth//widgets/team_admin_panel.dart';
import '../widgets/notification_tile.dart';

class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key});
  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen> {
  // bool _updating = false;

  // ✅ Only show these claim keys if present (edit to taste)
  static const List<_ClaimSpec> _shownClaimSpecs = [
    _ClaimSpec(key: 'email', label: 'Email', icon: Icons.email),
    _ClaimSpec(key: 'role', label: 'Role', icon: Icons.verified_user),
    _ClaimSpec(key: 'team', label: 'Team', icon: Icons.flag),
  ];

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(allClaimsProvider);
    // final emailOn = ref.watch(emailNotificationsOnProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
              // subtitle: Text(_formatValue(value)),
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
              Text('Team Admin Panel', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // Have a dropdown called "Current team users"
              // - trigger a backend function when clicked, to read them all from user_data and return a list
              // Add a popup dialog for the "Create New User" button, for email/pass input 
              // Card(child: CreateUserButton()),
              Card(child: TeamAdminPanel()),
              const SizedBox(height: 24),

              // ===== Admin/Rules Committee panel =====
              // Text('Admin Panel', style: Theme.of(context).textTheme.titleMedium),
              // const SizedBox(height: 24),
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

class _ClaimSpec {
  final String key;
  final String label;
  final IconData icon;
  const _ClaimSpec({required this.key, required this.label, required this.icon});
}

class CreateUserButton extends StatelessWidget {
  const CreateUserButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Example hard-coded values — replace with text fields or variables
        const testEmail = "dan.bernasconi@emiratesteamnz.com";

        await createUserFromFrontend(testEmail);
      },
      child: const Text("Create User"),
    );
  }
}
