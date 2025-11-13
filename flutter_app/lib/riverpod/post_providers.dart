// flutter_app/lib/riverpod/post_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/core/models/enquiry_status_filter.dart';
import 'package:rule_post/core/models/types.dart' show DocView;
import 'package:rule_post/riverpod/draft_provider.dart';
import 'package:rule_post/riverpod/post_streams.dart';
import 'package:rule_post/riverpod/user_detail.dart';


// 1) Returns public enquiries only
final publicEnquiriesProvider =
    StreamProvider.family<List<DocView>, EnquiryStatusFilter>((ref, statusFilter)  => publicEnquiriesStream(statusFilter: statusFilter));


// 2) Returns public enquiries and team drafts
final combinedEnquiriesProvider =
    StreamProvider.family<List<DocView>, ({EnquiryStatusFilter statusFilter})>((ref, args) {
  final teamId = ref.watch(teamProvider);
  ref.watch(draftIdsProvider(teamId)); // triggers refresh when new enquiry draft detected
  return combinedEnquiriesStream(teamId: teamId, statusFilter: args.statusFilter);
});