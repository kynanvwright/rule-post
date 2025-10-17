import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../core/widgets/draft_viewing.dart';

// This stops the left panel rebuilding on every navigation
final combinedEnquiriesProvider =
    StreamProvider.family<List<DocView>, ({String status, String? teamId})>((ref, params) {
  final stream = combinedEnquiriesStream(
    filter: {'status': params.status},
    teamId: params.teamId,
  )
      // .distinct(listEqualsByKeyFields)
      .shareReplay(maxSize: 1);

  return stream;
});
