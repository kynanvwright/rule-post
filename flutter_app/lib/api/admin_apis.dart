// flutter_app/lib/api/admin_apis.dart
import 'package:flutter/material.dart';

import 'package:rule_post/api/api_template.dart';
import 'package:rule_post/core/models/types.dart' show EnquiryConclusion, Json;

final api = ApiTemplate();

// Allows the RC to change the number of working days used for enquiry stage length calculations
Future<void> changeStageLength(
  BuildContext context,
  enquiryId,
  int newStageLength,
) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'changeStageLength',
    data: {'enquiryId': enquiryId.trim(), 'newStageLength': newStageLength},
    successMessage: 'Stage length changed to $newStageLength days.',
    failureMessage: 'Stage length failed to change.',
  );
}

// Allows the RC to close an enquiry, and state how it ended (interpretation, amendment, no result)
Future<void> closeEnquiry(
  BuildContext context,
  String enquiryId,
  EnquiryConclusion enquiryConclusion,
) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'closeEnquiry',
    data: {
      'enquiryId': enquiryId.trim(),
      'enquiryConclusion': enquiryConclusion.name,
    },
    successMessage: 'Enquiry closed.',
    failureMessage: 'Enquiry failed to close.',
  );
}

// Admin button, marks a post as unread for testing
Future<void> markPostUnread(
  BuildContext context,
  String enquiryId,
  String? responseId,
  String? commentId,
) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'markPostUnread',
    data: {
      'enquiryId': enquiryId.trim(),
      'responseId': responseId?.trim(),
      'commentId': commentId?.trim(),
    },
    successBuilder: (res) =>
        'Success: Attempted to mark ${res['attempted']} posts and succeeded with ${res['updated']}.',
    failureMessage: 'Function failed.',
  );
}

// Allows RC to publish Competitor responses earlier than scheduled
Future<void> publishCompetitorResponses(
  BuildContext context,
  String enquiryId,
) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'responseInstantPublisher',
    data: {'enquiryId': enquiryId.trim(), 'rcResponse': false},
    successBuilder: (res) => '${res['num_published']} responses published.',
    failureBuilder: (res) => 'Function failed due to: ${res['reason']}.',
  );
}

// Allows RC to publish their response earlier than scheduled
Future<void> publishRcResponse(BuildContext context, String enquiryId) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'responseInstantPublisher',
    data: {'enquiryId': enquiryId.trim(), 'rcResponse': true},
    successMessage: 'RC response published.',
    failureBuilder: (res) => 'Function failed due to: ${res['reason']}.',
  );
}

/// Retrieves author team identities for all posts in an enquiry.
/// Only accessible to admins and RC members.
/// Returns a map {postId: authorTeam} for efficient client-side caching.
/// No progress UI—intended for background fetching (e.g., Riverpod provider).
Future<Map<String, String>> getPostAuthorsForEnquiry(String enquiryId) async {
  try {
    final result = await api.call<Json>('getPostAuthorsForEnquiry', {
      'enquiryId': enquiryId.trim(),
    });

    // Extract authors map from response
    final authors = result['authors'] as Map<String, dynamic>?;
    if (authors == null) {
      return {};
    }

    // Convert to Map<String, String> (strip optional types)
    return authors.cast<String, String>();
  } catch (e) {
    debugPrint('[getPostAuthorsForEnquiry] Error: $e');
    rethrow;
  }
}

/// [TEST FUNCTION] Send a sample digest email to test deadline reminder formatting.
/// Only available to admins. Easy to remove after testing.
Future<void> testSendDigest(
  BuildContext context, {
  required String recipientEmail,
  bool includeDeadlines = true,
  bool includeActivity = true,
}) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'testSendDigest',
    data: {
      'recipientEmail': recipientEmail.trim(),
      'includeDeadlines': includeDeadlines,
      'includeActivity': includeActivity,
    },
    successMessage: 'Test email sent to $recipientEmail',
    failureMessage: 'Failed to send test email',
  );
}

// Allows the site admin to invite a new team admin for a specific team
Future<void> inviteTeamAdmin(
  BuildContext context, {
  required String email,
  required String team,
}) async {
  await api.callWithProgress<Json>(
    context: context,
    name: 'inviteTeamAdmin',
    data: {'email': email.trim(), 'team': team.trim()},
    successMessage: 'Team admin invite sent to $email for team $team.',
    failureMessage: 'Failed to invite team admin.',
  );
}
