// flutter_app/lib/api/change_stage_length.dart
import 'package:flutter/material.dart';
import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/widgets/types.dart';

final api = ApiTemplate();


Future<void> changeStageLength(BuildContext context, enquiryId, int newStageLength) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'changeStageLength', 
    data: {
      'enquiryId': enquiryId.trim(),
      'newStageLength' : newStageLength,
    },
    successMessage: 'Stage length changed to $newStageLength days.',
    failureMessage: 'Stage length failed to change.'
  );
}