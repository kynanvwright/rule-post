
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'post_streams.dart';
import 'enquiry_refresh_signal.dart';
import '../../riverpod/user_detail.dart';
import '../core/models/enquiry_status_filter.dart';
import 'package:rule_post/core/models/types.dart' show DocView;


// 1) Public (no auth)
final publicEnquiriesProvider =
    StreamProvider.family<List<DocView>, EnquiryStatusFilter>((ref, statusFilter)  => publicEnquiriesStream(statusFilter: statusFilter));

// 2) Private (needs teamId)
final combinedEnquiriesProvider =
    StreamProvider.family<List<DocView>, ({EnquiryStatusFilter statusFilter})>((ref, args) {
  final teamId = ref.watch(teamProvider);
  ref.watch(draftIdsProvider(teamId)); // triggers refresh when new enquiry draft detected
  return combinedEnquiriesStream(teamId: teamId, statusFilter: args.statusFilter);
});

// // 3) Router: returns *another* provider
// final effectiveEnquiriesProvider = Provider.family<
//     ProviderListenable<AsyncValue<List<DocView>>>,
//     ({String? teamId, String statusFilter})>((ref, args) {
//   return (args.teamId == null)
//       // pass the single positional argument (String)
//       ? publicEnquiriesProvider(args.statusFilter)
//       // pass the single positional argument (record)
//       : combinedEnquiriesProvider((
//           teamId: args.teamId,                // non-null here
//           statusFilter: args.statusFilter,
//         ));
// });
