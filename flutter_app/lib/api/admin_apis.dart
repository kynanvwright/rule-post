// flutter_app/lib/api/admin_apis.dart
import 'package:flutter/material.dart';
import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/widgets/types.dart';

final api = ApiTemplate();


// Allows the RC to change the number of working days used for enquiry stage length calculations
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


// Allows the RC to close an enquiry, and state how it ended (interpretation, amendment, no result)
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


// Admin button, marks a post as unread for testing
Future<void> markPostUnread(BuildContext context, String enquiryId, String? responseId, String? commentId,) async {
    await api.callWithProgress<Json>(
    context: context,
    name: 'markPostUnread', 
    data: {
      'enquiryId' : enquiryId.trim(),
      'responseId': responseId?.trim(),
      'commentId' : commentId?.trim(),
    },
    successBuilder: (res) => 'Success: Attempted to mark ${res['attempted']} posts and succeeded with ${res['updated']}.',
    failureMessage: 'Function failed.'
  );
}


// Allows RC to publish Competitor responses earlier than scheduled
Future<void> publishCompetitorResponses(BuildContext context, String enquiryId) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'responseInstantPublisher', 
    data: {
      'enquiryId': enquiryId.trim(),
      'rcResponse': false,
    },
    successBuilder: (res) => '${res['num_published']} responses published.',
    failureBuilder: (res) => 'Function failed due to: ${res['reason']}.'
  );
}


// Allows RC to publish their response earlier than scheduled
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