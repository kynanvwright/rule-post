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
      if (state.matchedLocation.contains('/responses'))
        _Crumb('Responses', '/enquiries/${p['enquiryId']}/responses', goParent: true, upLevels: 1), // go up one level, no page for responses
      if (p['responseId'] != null)
        _Crumb(responseLabel(), '/enquiries/${p['enquiryId']}/responses/${p['responseId']}'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            GestureDetector(
              onTap: () {
                final target = items[i].goParent
                    ? _parentOf(items[i].href, upLevels: items[i].upLevels)
                    : items[i].href;
                context.go(target);
              },
              child: Text(items[i].label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
  final bool goParent;      // <— when true, navigate one level up from href
  final int upLevels;       // <— how many levels to go up (default 1)
  _Crumb(this.label, this.href, {this.goParent = false, this.upLevels = 1});
}

String _parentOf(String href, {int upLevels = 1}) {
  final u = Uri.parse(href);
  final segs = List<String>.from(u.pathSegments);
  if (segs.isEmpty) return href;
  final cut = segs.length - upLevels.clamp(0, segs.length);
  final parentPath = '/${segs.take(cut).join('/')}';
  final qs = u.hasQuery ? '?${u.query}' : '';
  return '$parentPath$qs';
}
