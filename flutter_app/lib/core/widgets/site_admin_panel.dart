// flutter_app/lib/core/widgets/site_admin_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/api/admin_apis.dart' show inviteTeamAdmin;

/// Panel visible only to the site admin (role=admin).
/// Allows inviting a new team admin for a specified team.
class SiteAdminPanel extends ConsumerWidget {
  const SiteAdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite a new team admin to the site. '
              'They will receive an email to set their password and will be able '
              'to add/remove members for their team.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await _openInviteDialog(context);
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Invite team admin'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInviteDialog(BuildContext context) async {
    final result = await showDialog<_InviteTeamAdminInput>(
      context: context,
      builder: (_) => const _InviteTeamAdminDialog(),
    );
    if (result == null) return;
    if (!context.mounted) return;

    await inviteTeamAdmin(context, email: result.email, team: result.team);
  }
}

class _InviteTeamAdminInput {
  final String email;
  final String team;
  _InviteTeamAdminInput({required this.email, required this.team});
}

class _InviteTeamAdminDialog extends StatefulWidget {
  const _InviteTeamAdminDialog();

  @override
  State<_InviteTeamAdminDialog> createState() => _InviteTeamAdminDialogState();
}

class _InviteTeamAdminDialogState extends State<_InviteTeamAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite team admin'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'admin@team.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email required';
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
                  return ok ? null : 'Invalid email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _teamCtrl,
                decoration: const InputDecoration(
                  labelText: 'Team',
                  hintText: 'e.g. ETNZ, GBR, NZL',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Team required';
                  return null;
                },
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
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _InviteTeamAdminInput(
                email: _emailCtrl.text.trim(),
                team: _teamCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Send invite'),
        ),
      ],
    );
  }
}
