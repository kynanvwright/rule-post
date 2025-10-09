import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../riverpod/post_alias.dart';

class BreadcrumbBar extends ConsumerWidget  {
  const BreadcrumbBar({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = state.pathParameters;
    final latest = ref.watch(latestVisitProvider);
    String enquiryLabel() {
      return latest?.enquiryAlias ?? '';
    }
    String responseLabel() {
      return latest?.responseAlias ?? '';
    }

    final items = <_Crumb>[
      _Crumb('Enquiries', '/enquiries${state.uri.hasQuery ? '?${state.uri.query}' : ''}'),
      if (p['enquiryId'] != null)
        _Crumb(enquiryLabel(), '/enquiries/${p['enquiryId']}'),
      if (p['enquiryId'] != null && p['responseId'] != null)
        _Crumb(responseLabel(), '/enquiries/${p['enquiryId']}/${p['responseId']}'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                  onTap: () {
                    final target = items[i].href;
                    context.go(target);
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Text(
                        items[i].label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ),
            if (i < items.length - 1) const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(' / '),
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb {
  final String label;
  final String href;
  _Crumb(this.label, this.href);
}
