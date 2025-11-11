// flutter_app/lib/api/close_enquiry_api.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/widgets/types.dart';

final api = ApiTemplate();


Future<void> closeEnquiry(BuildContext context, String enquiryId, EnquiryConclusion enquiryConclusion) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'closeEnquiry', 
    data: {
      'enquiryId': enquiryId.trim(),
      'enquiryConclusion': enquiryConclusion.name,
    },
    successMessage: 'Enquiry closed.',
    failureMessage: 'Enquiry failed to close.'
  );
}