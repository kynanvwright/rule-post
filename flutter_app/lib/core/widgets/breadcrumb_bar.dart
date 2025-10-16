// breadcrumb_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/nav.dart';
import '../../riverpod/post_alias.dart';
import '../../debug/nav_log.dart'; // 👈 add

class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swBuild = NavLog.sw('[CRUMB] build');
    final p = state.pathParameters;
    final enquiryId = p['enquiryId'];
    final responseId = p['responseId'];

    final enquiryAlias = enquiryId == null
        ? null
        : ref.watch(enquiryAliasProvider(enquiryId));
    final responseAlias = (enquiryId == null || responseId == null)
        ? null
        : ref.watch(responseAliasProvider((enquiryId: enquiryId, responseId: responseId)));

    NavLog.p('[CRUMB] route="${state.uri}" '
        'enquiryId=$enquiryId (${_aliasState(enquiryAlias)}) '
        'responseId=$responseId (${_aliasState(responseAlias)})');

    String enquiryLabel() =>
        (enquiryAlias != null && enquiryAlias.isNotEmpty) ? enquiryAlias : '';

    String responseLabel() =>
        (responseAlias != null && responseAlias.isNotEmpty) ? responseAlias : '';

    final crumbs = <_Crumb>[
      _Crumb(
        'Enquiries',
        onTap: () {
          final seq = NavLog.nextSeq();
          final tapSW = NavLog.sw('[$seq][CRUMB] tap "Enquiries"');
          NavLog.p('[$seq][CRUMB] TAPPED root (from="${GoRouter.of(context).routeInformationProvider.value.uri}")');
          NavLog.end(tapSW, '[$seq][CRUMB] tap "Enquiries"');
          Nav.goHome(context);
        },
        key: const ValueKey('root:enquiries'),
      ),
      if (enquiryId != null)
        _Crumb(
          enquiryLabel(),
          onTap: () {
            final seq = NavLog.nextSeq();
            final tapSW = NavLog.sw('[$seq][CRUMB] tap enquiry "$enquiryId"');
            NavLog.p('[$seq][CRUMB] TAPPED enquiry="$enquiryId" label="${enquiryLabel()}"');
            NavLog.end(tapSW, '[$seq][CRUMB] tap enquiry "$enquiryId"');
            Nav.goEnquiry(context, enquiryId);
          },
          key: ValueKey('enquiry:$enquiryId'),
        ),
      if (enquiryId != null && responseId != null)
        _Crumb(
          responseLabel(),
          onTap: () {
            final seq = NavLog.nextSeq();
            final tapSW = NavLog.sw('[$seq][CRUMB] tap response "$responseId"');
            NavLog.p('[$seq][CRUMB] TAPPED response="$responseId" label="${responseLabel()}"');
            NavLog.end(tapSW, '[$seq][CRUMB] tap response "$responseId"');
            Nav.goResponse(context, enquiryId, responseId);
          },
          key: ValueKey('response:$enquiryId/$responseId'),
        ),
    ];

    final w = SingleChildScrollView(
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
                    key: ValueKey(crumbs[i].label),
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

    NavLog.end(swBuild, '[CRUMB] build'); // 👈 how long the build took
    return w;
  }
}

String _aliasState(String? v) {
  if (v == null) return 'alias=null (loading)';
  if (v.isEmpty) return 'alias="" (not ready)';
  return 'alias="$v"';
}

class _Crumb {
  final String label;
  final VoidCallback onTap;
  final Key? key;
  _Crumb(this.label, {required this.onTap, this.key});
}
