// flutter_app/lib/core/widgets/breadcrumb_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rule_post/navigation/nav.dart';
import 'package:rule_post/riverpod/post_alias_providers.dart';


// Used to indicate the currently viewed post, and navigate to other posts
class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = state.pathParameters;
    final enquiryId  = p['enquiryId'];
    final responseId = p['responseId'];

    // Read current alias values (they start as null; something else sets them later)
    final enquiryAlias  = enquiryId == null
        ? null
        : ref.watch(enquiryAliasProvider(enquiryId));

    final responseAlias = (enquiryId == null || responseId == null)
        ? null
        : ref.watch(responseAliasProvider((enquiryId: enquiryId, responseId: responseId)));

    bool hasText(String? s) => s != null && s.trim().isNotEmpty;

    final needsEnquiry  = enquiryId != null;
    final needsResponse = enquiryId != null && responseId != null;

    // Gate rendering until all required pieces exist (and have text if you want)
    final ready =
        (!needsEnquiry  || hasText(enquiryAlias)) &&
        (!needsResponse || hasText(responseAlias));

    // Keep header height stable while waiting
    const barHeight = 32.0;
    if (!ready) return const SizedBox(height: barHeight);

    // Build labels now that we know they exist
    final enquiryLabel  = needsEnquiry  ? enquiryAlias!.trim()  : '';
    final responseLabel = needsResponse ? responseAlias!.trim() : '';

    final crumbs = <_Crumb>[
      _Crumb('Enquiries', () => Nav.goHome(context),
          key: const ValueKey('root:enquiries')),
      if (needsEnquiry)
        _Crumb(
          enquiryLabel,
          () => Nav.goEnquiry(context, enquiryId),
          key: ValueKey('enquiry:$enquiryId'),
        ),
      if (needsResponse)
        _Crumb(
          responseLabel,
          () => Nav.goResponse(context, enquiryId, responseId),
          key: ValueKey('response:$enquiryId/$responseId'),
        ),
    ];

    // Fade in once (no per-crumb flicker)
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
                  key: crumbs[i].key,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
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