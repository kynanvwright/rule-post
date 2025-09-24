// post_alias.dart or top of your widget file
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LatestVisit {
  final String enquiryId;
  final String? enquiryAlias;   // e.g. "RE#120"
  final String? responseId;     // null => viewing an enquiry
  final String? responseAlias;  // e.g. "R1.2"
  const LatestVisit({
    required this.enquiryId,
    this.enquiryAlias,
    this.responseId,
    this.responseAlias,
  });

  LatestVisit copyWith({
    String? enquiryId,
    String? enquiryAlias,
    String? responseId,
    String? responseAlias,
  }) => LatestVisit(
    enquiryId: enquiryId ?? this.enquiryId,
    enquiryAlias: enquiryAlias ?? this.enquiryAlias,
    responseId: responseId ?? this.responseId,
    responseAlias: responseAlias ?? this.responseAlias,
  );
}

final latestVisitProvider = StateProvider<LatestVisit?>((ref) => null);

// // usage in a widget:

// // call once (e.g., in initState of a ConsumerStatefulWidget or top of build in ConsumerWidget)
// ref.read(latestVisitProvider.notifier).state = LatestVisit(
//   enquiryId: enquiryId,
//   enquiryAlias: enquiryAliasMaybe, // can be null initially
// );

// // later when alias arrives (from Firestore/provider):
// ref.read(latestVisitProvider.notifier).state =
//   ref.read(latestVisitProvider)!.copyWith(enquiryAlias: 'RE#$enquiryNumber');

//   // initial record (ids only are fine)
// ref.read(latestVisitProvider.notifier).state = LatestVisit(
//   enquiryId: enquiryId,
//   responseId: responseId,
// );

// // later, fill aliases when you have them:
// final curr = ref.read(latestVisitProvider);
// if (curr != null && curr.enquiryId == enquiryId && curr.responseId == responseId) {
//   ref.read(latestVisitProvider.notifier).state = curr.copyWith(
//     enquiryAlias: 'RE#$enquiryNumber',
//     responseAlias: 'R$round.$respNumber',
//   );
// }

// Consumer(
//   builder: (context, ref, _) {
//     final v = ref.watch(latestVisitProvider);
//     if (v == null) return const SizedBox.shrink();
//     final enquiryText = v.enquiryAlias ?? 'E-${v.enquiryId}';
//     final responseText = v.responseId == null
//         ? null
//         : (v.responseAlias ?? 'R-${v.responseId}');
//     return Row(
//       children: [
//         Chip(label: Text(enquiryText)),
//         if (responseText != null) ...[
//           const SizedBox(width: 8),
//           Chip(label: Text(responseText)),
//         ],
//       ],
//     );
//   },
// );
