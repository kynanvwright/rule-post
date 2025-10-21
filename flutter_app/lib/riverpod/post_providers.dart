
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/doc_view.dart';
import 'post_streams.dart';
import 'user_detail.dart';

// 1) Public (no auth)
final publicEnquiriesProvider =
    StreamProvider.family<List<DocView>, String>((ref, statusFilter)  => publicEnquiriesStream(statusFilter: statusFilter));

// 2) Private (needs teamId)
final teamEnquiriesProvider =
    StreamProvider.family<List<DocView>, ({String teamId, String statusFilter})>((ref, args) {
  return combinedEnquiriesStream(teamId: args.teamId, statusFilter: args.statusFilter);
});

// 3) Router: returns *another* provider
final effectiveEnquiriesProvider = Provider.family<
    ProviderListenable<AsyncValue<List<DocView>>>,
    String>((ref, statusFilter) {
  final teamId = ref.watch(teamProvider);

  return (teamId == null)
      ? publicEnquiriesProvider(statusFilter)
      : teamEnquiriesProvider((teamId: teamId, statusFilter: statusFilter));
});
