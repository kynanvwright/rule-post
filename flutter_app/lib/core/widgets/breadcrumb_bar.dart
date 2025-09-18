import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final p = state.pathParameters;
    final items = <_Crumb>[
      _Crumb('Enquiries', '/enquiries${state.uri.hasQuery ? '?${state.uri.query}' : ''}'),
      if (p['enquiryId'] != null)
        _Crumb('E-${p['enquiryId']}', '/enquiries/${p['enquiryId']}'),
      if (state.matchedLocation.contains('/responses'))
        _Crumb('Responses', '/enquiries/${p['enquiryId']}/responses'),
      if (p['responseId'] != null)
        _Crumb('R-${p['responseId']}', '/enquiries/${p['enquiryId']}/responses/${p['responseId']}'),
      if (state.matchedLocation.contains('/comments'))
        _Crumb('Comments', '/enquiries/${p['enquiryId']}/responses/${p['responseId']}/comments'),
      if (p['commentId'] != null)
        _Crumb('C-${p['commentId']}', state.matchedLocation),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            GestureDetector(
              onTap: () => context.go(items[i].href),
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
  _Crumb(this.label, this.href);
}
