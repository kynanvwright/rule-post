// flutter_app/lib/api/user_apis.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/widgets/types.dart';

final api = ApiTemplate();


// Used by the team admin to add new user to their team
Future<void> createUserFromFrontend(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'createUserWithProfile', 
    data: {'email': email,},
    successMessage: 'User created for the email: $email.',
    failureMessage: 'User creation function failed.'
  );
}


// Used by the team admin to remove a user from their team
Future<void> deleteUserByEmail(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'deleteUser', 
    data: {'email': email,},
    successMessage: 'User deleted.',
    failureMessage: 'User deletion failed.'
  );
}


// Used by the team admin to view which users are assigned to their team
Future<List<String>> listTeamUsers() async {
  // called without dialog as this function is refreshed by other operations
  final result = await api.call<Json>('listTeamUsers', {});
  final data = result['emails'];

  if (data is List) {
    return data.map((e) => e.toString()).toList();
  } else {
    throw StateError(
        'Unexpected response format: expected List<String>, got ${data.runtimeType}');
  }
}