
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/doc_view.dart';
import 'post_streams.dart';

// 1) Public (no auth)
final publicEnquiriesProvider =
    StreamProvider.family<List<DocView>, String>((ref, statusFilter)  => publicEnquiriesStream(statusFilter: statusFilter));

// 2) Private (needs teamId)
final combinedEnquiriesProvider =
    StreamProvider.family<List<DocView>, ({String? teamId, String statusFilter})>((ref, args) {
  return combinedEnquiriesStream(teamId: args.teamId, statusFilter: args.statusFilter);
});

// 3) Router: returns *another* provider
final effectiveEnquiriesProvider = Provider.family<
    ProviderListenable<AsyncValue<List<DocView>>>,
    ({String? teamId, String statusFilter})>((ref, args) {
  return (args.teamId == null)
      // pass the single positional argument (String)
      ? publicEnquiriesProvider(args.statusFilter)
      // pass the single positional argument (record)
      : combinedEnquiriesProvider((
          teamId: args.teamId!,                // non-null here
          statusFilter: args.statusFilter,
        ));
});
