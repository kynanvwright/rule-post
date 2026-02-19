// flutter_app/lib/riverpod/team_members_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:rule_post/core/models/types.dart' show TeamUser;
import 'package:rule_post/riverpod/user_detail.dart';

// retrieve the users with the same team as the current user
final teamMembersProvider = StreamProvider.autoDispose<List<TeamUser>>((ref) {
  final team = ref.watch(teamProvider);

  if (team == null || team.isEmpty) {
    // No team yet → stream an empty list (keeps UI simple)
    return const Stream<List<TeamUser>>.empty();
  }

  return streamUsersByTeam(team).map((rows) {
    return rows.map((data) {
      final email = (data['email'] as String?) ?? '';
      final displayName =
          (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String)
          : (email.isNotEmpty ? getNameFromEmail(email) : 'Unknown');

      final uid = (data['uid'] as String?) ?? '';
      final disabled = (data['disabled'] as bool?) ?? false;

      return TeamUser(
        uid: uid,
        email: email,
        displayName: displayName,
        disabled: disabled,
      );
    }).toList()..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  });
});

// stream for the provider
Stream<List<Map<String, dynamic>>> streamUsersByTeam(String team) {
  final db = FirebaseFirestore.instance;

  return db
      .collection('user_data')
      .where('team', isEqualTo: team)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) {
          final data = d.data();
          return {'uid': d.id, ...data};
        }).toList(),
      );
}

// helper to extract a display name from the email address
String getNameFromEmail(String email) {
  final localPart = email.split('@')[0];
  final dotParts = localPart.split('.');

  if (dotParts.length > 1) {
    return dotParts
        .map(
          (part) => part.isNotEmpty
              ? part[0].toUpperCase() + part.substring(1).toLowerCase()
              : "",
        )
        .join(' ');
  }

  return localPart.isNotEmpty
      ? localPart[0].toUpperCase() + localPart.substring(1).toLowerCase()
      : "";
}
