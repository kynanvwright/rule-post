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
        (enquiryAlias != null && enquiryAlias.isNotEmpty) ? enquiryAlias : '';

    String responseLabel() =>
        (responseAlias != null && responseAlias.isNotEmpty) ? responseAlias : '';

    final crumbs = <_Crumb>[
      _Crumb('Enquiries', () => Nav.goHome(context),
          key: const ValueKey('root:enquiries')),
      if (enquiryId != null)
        _Crumb(
          enquiryLabel(),
          () => Nav.goEnquiry(context, enquiryId),
          key: ValueKey('enquiry:$enquiryId'),
        ),
      if (enquiryId != null && responseId != null)
        _Crumb(
          responseLabel(),
          () => Nav.goResponse(context, enquiryId, responseId),
          key: ValueKey('response:$enquiryId/$responseId'),
        ),
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
                  key: crumbs[i].key, // 👈 stable key
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: AnimatedSwitcher( // optional: smooth fade-in when alias arrives
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      crumbs[i].label,
                      key: ValueKey(crumbs[i].label), // switcher’s internal key
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                    ),
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
  final Key? key;
  _Crumb(this.label, this.onTap, {this.key});
}
