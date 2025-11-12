// flutter_app/lib/auth/widgets/team_admin_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/api/user_apis.dart';

// ───────────────────────── Models ─────────────────────────
class TeamUser {
  final String email;
  final String displayName;
  TeamUser({required this.email, required this.displayName});
}

// ─────────────────────── Providers ───────────────────────
final teamMembersProvider = StateNotifierProvider<TeamMembersController, AsyncValue<List<TeamUser>>>(
  (ref) => TeamMembersController(),
);

class TeamMembersController extends StateNotifier<AsyncValue<List<TeamUser>>> {
  TeamMembersController() : super(const AsyncValue.data([]));

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final result = await listTeamUsers();
      final users = result.map<TeamUser>((email) {
        return TeamUser(
          email: email,
          displayName: getNameFromEmail(email),
        );
      }).toList();
      state = AsyncValue.data(users);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// final createMemberProvider =
//     FutureProvider.family<void, CreateMemberInput>((ref, input) async {
//   await createUserFromFrontend(input.context, input.email);
// });

class CreateMemberInput {
  final BuildContext context;
  final String email;
  final bool isAdmin;
  CreateMemberInput({required this.email, required this.context, this.isAdmin = false});
}

// ───────────────────────── Widget ────────────────────────
class TeamAdminPanel extends ConsumerWidget {
  const TeamAdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current team members block
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Team member list:'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Fetch members',
                  onPressed: () => ref.read(teamMembersProvider.notifier).fetch(),
                  icon: const Icon(Icons.refresh),
                ),
                const Icon(Icons.expand_more),
              ]),
              children: [
                switch (members) {
                  AsyncData(:final value) => value.isEmpty
                      ? const ListTile(title: Text('No members yet. Click refresh to load.'))
                      : _MembersList(value),
                  AsyncError(:final error) => ListTile(
                      title: const Text('Failed to load members'),
                      subtitle: Text(error.toString()),
                      leading: const Icon(Icons.error_outline),
                    ),
                  _ => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                }
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await _openAddDialog(context, ref);
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add team member'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<CreateMemberInput>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (result == null) return;
    if (!context.mounted) return;
    try {
    await createUserFromFrontend(context, result.email);
    } finally {
      await ref.read(teamMembersProvider.notifier).fetch();
    }
  }
}

// ────────────────────── Parts: Members List ──────────────────────
class _MembersList extends ConsumerWidget {
  const _MembersList(this.members);
  final List<TeamUser> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: members.map((m) {
        return ListTile(
          leading: CircleAvatar(
            child: Text(_initials(m.displayName)),
          ),
          title: Text(m.displayName),
          subtitle: Text(m.email),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await deleteUserByEmail(context, m.email);
              await ref.read(teamMembersProvider.notifier).fetch();
            },
          ),
        );
      }).toList(),
    );
  }


  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

// ───────────────────── Parts: Add Member Dialog ─────────────────────
class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKeyB = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  bool _isAdmin = false;

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add team member'),
      content: Form(
        key: _formKeyB,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email', hintText: 'user@company.com'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email required';
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
                  return ok ? null : 'Invalid email';
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _isAdmin,
                onChanged: (v) => setState(() => _isAdmin = v ?? false),
                title: const Text('Make team admin'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_formKeyB.currentState!.validate()) return;
            Navigator.pop(
              context,
              CreateMemberInput(email: _email.text.trim(), context: context, isAdmin: _isAdmin),
            );
          },
          child: const Text('Create'),
        )
      ],
    );
  }
}

String getNameFromEmail(String email) {
  // Get everything before the @
  final localPart = email.split('@')[0];

  // Try splitting by "."
  final dotParts = localPart.split('.');

  if (dotParts.length > 1) {
    // Capitalize each part
    return dotParts
        .map((part) =>
            part.isNotEmpty
                ? part[0].toUpperCase() + part.substring(1).toLowerCase()
                : "")
        .join(' ');
  }

  // Fallback: just capitalize the localPart
  return localPart.isNotEmpty
      ? localPart[0].toUpperCase() + localPart.substring(1).toLowerCase()
      : "";
}