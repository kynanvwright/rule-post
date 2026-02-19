// flutter_app/lib/api/user_apis.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/models/types.dart';

final api = ApiTemplate();

// Used by the team admin to add new user to their team
Future<void> createUserFromFrontend(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'createUserWithProfile',
    data: {'email': email},
    successMessage: 'User created for the email: $email.',
    failureMessage: 'User creation function failed.',
  );
}

// Used by the team admin to remove a user from their team
Future<void> deleteUserByEmail(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'deleteUser',
    data: {'email': email},
    successMessage: 'User deleted.',
    failureMessage: 'User deletion failed.',
  );
}

// Used by the team admin to lock or unlock a team member's account
Future<void> toggleUserLock(
  BuildContext context, {
  required String email,
  required bool disabled,
}) async {
  final action = disabled ? 'locked' : 'unlocked';
  await api.callWithProgress<Json>(
    context: context,
    name: 'toggleUserLock',
    data: {'email': email, 'disabled': disabled},
    successMessage: 'User $action.',
    failureMessage: 'Failed to $action user.',
  );
}

// Used by the team admin to send a password reset email to a team member
Future<void> sendPasswordResetEmail(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'sendPasswordReset',
    data: {'email': email},
    successMessage: 'Password reset email sent to $email.',
    failureMessage: 'Failed to send password reset email.',
  );
}
