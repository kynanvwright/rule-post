// breadcrumb_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/nav.dart';
import '../../riverpod/post_alias.dart';

class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = state.pathParameters;
    final enquiryId = p['enquiryId'];
    final responseId = p['responseId'];

    final enquiryAlias = enquiryId == null
        ? null
        : ref.watch(enquiryAliasProvider(enquiryId));
    final responseAlias = (enquiryId == null || responseId == null)
        ? null
        : ref.watch(responseAliasProvider((enquiryId: enquiryId, responseId: responseId)));

    String enquiryLabel() =>
        (enquiryAlias != null && enquiryAlias.isNotEmpty)
            ? enquiryAlias
            : (enquiryId != null ? 'Enquiry $enquiryId' : 'Enquiry');

    String responseLabel() =>
        (responseAlias != null && responseAlias.isNotEmpty)
            ? responseAlias
            : (responseId != null ? 'Response $responseId' : 'Response');

    final crumbs = <_Crumb>[
      _Crumb('Enquiries', () => Nav.goHome(context)),
      if (enquiryId != null)
        _Crumb(enquiryLabel(), () => Nav.pushEnquiry(context, enquiryId)),
      if (enquiryId != null && responseId != null)
        _Crumb(responseLabel(), () => Nav.pushResponse(context, enquiryId, responseId)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < crumbs.length; i++) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: crumbs[i].onTap,
                child: Container(
                  key: ValueKey(crumbs[i].label),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    crumbs[i].label,
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ),
              ),
            ),
            if (i < crumbs.length - 1)
              const Padding(
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
  final VoidCallback onTap;
  _Crumb(this.label, this.onTap);
}
