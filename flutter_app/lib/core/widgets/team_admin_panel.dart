// flutter_app/lib/auth/widgets/team_admin_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/api/user_apis.dart';
import 'package:rule_post/core/models/types.dart'
    show CreateMemberInput, TeamUser;
import 'package:rule_post/riverpod/team_members_provider.dart'
    show teamMembersProvider;

// Panel for the designated team admin to manage team members
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
              initiallyExpanded: true,
              title: const Text('Team member list:'),
              // Remove trailing entirely to keep default expand/collapse chevron
              children: [
                members.when(
                  data: (value) => value.isEmpty
                      ? const ListTile(title: Text('No members yet.'))
                      : _MembersList(value),
                  error: (error, _) => ListTile(
                    title: const Text('Failed to load members'),
                    subtitle: Text(error.toString()),
                    leading: const Icon(Icons.error_outline),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
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

    await createUserFromFrontend(context, result.email);
    // stream updates automatically
  }
}

// Shows which users belong to the tead admin's team
class _MembersList extends ConsumerWidget {
  const _MembersList(this.members);
  final List<TeamUser> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: members.map((m) {
        return ListTile(
          leading: CircleAvatar(child: Text(_initials(m.displayName))),
          title: Text(m.displayName),
          subtitle: Text(m.email),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.lock_reset),
                tooltip: 'Send password reset email',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Reset password'),
                      content: Text(
                        'Send a password reset email to ${m.email}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Send'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  await sendPasswordResetEmail(context, m.email);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete team member',
                onPressed: () async {
                  await deleteUserByEmail(context, m.email);
                },
              ),
            ],
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
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'user@company.com',
                ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKeyB.currentState!.validate()) return;
            Navigator.pop(
              context,
              CreateMemberInput(
                email: _email.text.trim(),
                context: context,
                isAdmin: _isAdmin,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
