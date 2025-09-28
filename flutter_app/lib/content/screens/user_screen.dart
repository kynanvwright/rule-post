//content/screens/user_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/user_detail.dart';
import '../../api/create_user_api.dart';
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
          // final pretty = const JsonEncoder.withIndent('  ')
          //     .convert(claims.isEmpty ? {'(no custom claims)': true} : claims);

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
              // Card(
              //   child: Builder(
              //     builder: (context) {
              //       final enabled = ref.watch(emailNotificationsOnProvider);
              //       return SwitchListTile.adaptive(
              //         title: const Text('Email notifications'),
              //         value: enabled,
              //         onChanged: (next) async {
              //           debugPrint('Toggled to $next');
              //           await ref.read(updateEmailNotificationsProvider(next).future);
              //           debugPrint('Callable finished');
              //         },
              //       );
              //     },
              //   ),
              // ),
              const SizedBox(height: 24),

              // ===== Team Admin panel =====
              Text('Team Admin Panel', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // Add list of users for the user's team (need backend query for this)
              // Consider adding a popup for the "Create New User" button, for input 
              Card(child: CreateUserButton()),
              const SizedBox(height: 24),

              // ===== Admin/Rules Committee panel =====
              // Text('Admin Panel', style: Theme.of(context).textTheme.titleMedium),
              // const SizedBox(height: 8),
              // Add list of users for the user's team (need backend query for this)
              // Consider adding a popup for the "Create New User" button, for input 
              // Card(child: CreateUserButton()),
              // const SizedBox(height: 24),

              // // (Optional) Debug view of all claims
              // ExpansionTile(
              //   tilePadding: EdgeInsets.zero,
              //   title: const Text('All custom claims (debug)'),
              //   children: [
              //     Container(
              //       width: double.infinity,
              //       padding: const EdgeInsets.all(12),
              //       decoration: BoxDecoration(
              //         borderRadius: BorderRadius.circular(8),
              //         border: Border.all(color: Theme.of(context).dividerColor),
              //       ),
              //       child: SingleChildScrollView(
              //         scrollDirection: Axis.horizontal,
              //         child: Text(
              //           pretty,
              //           style: const TextStyle(fontFamily: 'monospace'),
              //         ),
              //       ),
              //     ),
              //     const SizedBox(height: 8),
              //   ],
              // ),
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
        const testPassword = "test1234";

        await createUserFromFrontend(testEmail, testPassword);
      },
      child: const Text("Create User"),
    );
  }
}
