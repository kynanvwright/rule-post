// flutter_app/lib/riverpod/team_members_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/api/user_apis.dart';
import 'package:rule_post/core/models/types.dart' show TeamUser;


// Used in the team admin panel to list current members
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


// for showing names in the admin panel
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
