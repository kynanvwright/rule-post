import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/post_lists.dart';

class LeftPaneSwitcher extends StatelessWidget {
  const LeftPaneSwitcher({super.key, required this.state});
  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final p = state.pathParameters;
    final loc = state.matchedLocation;

    if (loc.startsWith('/enquiries/') && loc.contains('/responses/')) {
      // Responses or Comments level → list responses for enquiry
      return ResponsesList(enquiryId: p['enquiryId']!);
    }

    if (loc.startsWith('/enquiries/') && !loc.contains('/responses')) {
      // Enquiry detail level → still show the responses list? (Optional)
      // If you prefer, keep showing the Enquiry list here.
      return EnquiriesList( // or ResponsesList(...)
        filter: state.uri.queryParameters, // e.g. status=open
      );
    }

    // Top level: enquiries list
    return EnquiriesList(filter: state.uri.queryParameters);
  }
}
