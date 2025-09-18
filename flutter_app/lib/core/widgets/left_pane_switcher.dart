import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/post_lists.dart';
import '../../content/widgets/new_post_button.dart';

class LeftPaneSwitcher extends StatelessWidget {
  const LeftPaneSwitcher({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final p = state.pathParameters;
    final loc = state.matchedLocation;
    final qp = state.uri.queryParameters;

    // Responses or Comments level → show Responses list
    if (loc.startsWith('/enquiries/') && loc.contains('/responses/')) {
      final enquiryId = p['enquiryId']!;
      return LeftPaneFrame(
        title: 'Responses',
        actions: const [], // (optional) add "New Response" later
        child: ResponsesList(enquiryId: enquiryId),
      );
    }

    // Enquiry detail level → keep Enquiries list
    if (loc.startsWith('/enquiries/') && !loc.contains('/responses')) {
      return LeftPaneFrame(
        title: 'Enquiries',
        actions: [
          NewPostButton(type: PostType.enquiry),
        ],
        child: EnquiriesList(filter: qp),
      );
    }

    // Top level
    return LeftPaneFrame(
      title: 'Enquiries',
      actions: [
        NewPostButton(type: PostType.enquiry),
      ],
      child: EnquiriesList(filter: qp),
    );
  }
}

class LeftPaneFrame extends StatelessWidget {
  const LeftPaneFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
