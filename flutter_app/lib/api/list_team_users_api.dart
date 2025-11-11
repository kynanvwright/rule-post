// flutter_app/lib/api/list_team_users_api.dart
import 'package:flutter/foundation.dart';

import 'api_template.dart';
import '../../core/widgets/types.dart';

final api = ApiTemplate();


Future<List<String>> listTeamUsers() async {
  final result = await api.call<Json>('listTeamUsers', {});
  final data = result['emails'];

  if (data is List) {
    final emails = data.map((e) => e.toString()).toList();
    debugPrint('✅ Loaded ${emails.length} emails: $emails');
    return emails;
  } else {
    throw StateError(
        'Unexpected response format: expected List<String>, got ${data.runtimeType}');
  }
}