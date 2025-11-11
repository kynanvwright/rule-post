// flutter_app/lib/api/user_apis.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/widgets/types.dart';

final api = ApiTemplate();


Future<void> createUserFromFrontend(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'createUserWithProfile', 
    data: {'email': email,},
    successMessage: 'User created for the email: $email.',
    failureMessage: 'User creation function failed.'
  );
}


Future<void> deleteUserByEmail(BuildContext context, String email) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'deleteUser', 
    data: {'email': email,},
    successMessage: 'User deleted.',
    failureMessage: 'User deletion failed.'
  );
}