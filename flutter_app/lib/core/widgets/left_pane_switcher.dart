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
        title: 'Files',
        actions: const [], // (optional) add "New Response" later
        child: ResponsesList(enquiryId: enquiryId),
      );
    }

    // Enquiry detail level → keep Enquiries list
    if (loc.startsWith('/enquiries/') && !loc.contains('/responses')) {
      return LeftPaneFrame(
        title: 'Files',
        actions: [
          NewPostButton(type: PostType.enquiry),
        ],
        child: EnquiriesList(filter: qp),
      );
    }

    // Top level
    return LeftPaneFrame(
      title: 'Files',
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
    this.title,
    this.actions = const <Widget>[],
    this.header,
    required this.child,
  });

  final String? title;
  final List<Widget> actions;
  final Widget? header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: header ??
                Row(
                  children: [
                    if (title != null)
                      Text(title!,
                          style: Theme.of(context).textTheme.titleMedium),
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


