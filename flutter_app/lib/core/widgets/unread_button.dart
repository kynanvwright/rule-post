// unread_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/read_receipts.dart';

class UnreadBellButton extends ConsumerWidget {
  const UnreadBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.notifications_none),
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) {
            return Consumer(
              builder: (ctx, ref, _) {
                final asyncVal = ref.watch(readReceiptProvider);

                return AlertDialog(
                  title: const Text('Unread summary'),
                  content: asyncVal.when(
                    loading: () => const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                    error: (err, stack) => Text('Error: $err'),
                    data: (map) {
                      final counts = map['counts'] as List<int>;
                      final enquiriesUnread = counts[0];
                      final responsesUnread = counts[1];
                      final commentsUnread  = counts[2];

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enquiries unread: $enquiriesUnread'),
                          Text('Responses unread: $responsesUnread'),
                          Text('Comments unread:  $commentsUnread'),
                        ],
                      );
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
