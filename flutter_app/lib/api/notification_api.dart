// flutter_app/lib/api/notification_api.dart
// import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/models/types.dart' show Json;

final api = ApiTemplate();


// Allows users to choose if they want to get regular email alerts for new posts
Future<bool> toggleEmailNotifications(bool emailNotificationsOn) async {
  final result = await api.call<Json>(
    'toggleEmailNotifications', 
    {'enabled': emailNotificationsOn}
  );
  return result['emailNotificationsOn'];
}

 
Future<String> setEmailNotificationScope(String scope) async {
  final result = await api.call<Json>(
    'toggleEmailNotifications',
    {'scope': scope},
  );
  return (result['emailNotificationsScope'] as String?) ?? 'all';
}
// version with progress dialog
// Future<bool> toggleEmailNotifications(BuildContext context, bool emailNotificationsOn) async {
  //   final result = await api.callWithProgress<Json>(
  //   context: context,
  //   name: 'toggleEmailNotifications', 
  //   data: {
  //     'enabled': emailNotificationsOn
  //   },
  //   successMessage: 'Enquiry closed.',
  //   failureMessage: 'Enquiry failed to close.',
  //   autoCloseAfter: const Duration(seconds: 1),
  // );
  // return result['emailNotificationsOn'];
// }