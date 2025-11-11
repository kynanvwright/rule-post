// flutter_app/lib/api/publish_rc_response.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/widgets/types.dart';

final api = ApiTemplate();

Future<void> publishRcResponse(BuildContext context, String enquiryId) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'responseInstantPublisher', 
    data: {
      'enquiryId': enquiryId.trim(),
      'rcResponse': true,
    },
    successMessage: 'RC response published.',
    failureBuilder: (res) => 'Function failed due to: ${res['reason']}.'
  );
}