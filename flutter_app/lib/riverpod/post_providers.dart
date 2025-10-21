
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


// // (Optional) Clear private caches on logout to avoid stale/leak
// final _authWatcher = Provider<void>((ref) {
//   ref.listen<String?>(teamProvider, (prev, next) {
//     if (next == null && prev != null) {
//       ref.invalidate(teamEnquiriesProvider); // nukes all team instances
//     }
//   });
// });

// // 4) Usage in UI (double-watch)
// @override
// Widget build(BuildContext context, WidgetRef ref) {
//   ref.watch(_authWatcher); // enable optional cleanup
//   final chosen = ref.watch(effectiveEnquiriesProvider);
//   final itemsAsync = ref.watch(chosen);

//   return itemsAsync.when(
//     data: (items) => /* ... */,
//     loading: () => /* spinner or keep-stale-if-you-want */,
//     error: (e, _) => /* ... */,
//   );
// }
