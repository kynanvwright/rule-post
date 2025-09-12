import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/post_scaffold.dart';
import '../../core/widgets/category_sidebar.dart';
import '../../core/widgets/post_list.dart';
import '../../core/widgets/pane_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.category,
    this.enquiryId,
  });

  final String category;
  final String? enquiryId;

  @override
  Widget build(BuildContext context) {
    // Example categories
    final categories = [
      ('all', 'All Enquiries'),
      ('mine', 'My Enquiries'),
      ('open', 'Open'),
      ('closed', 'Closed'),
    ];

    // Dummy list of items — replace with Firestore query later
    final items = List.generate(
      6,
      (i) => EnquiryListEntry(
        id: '$i',
        title: 'Enquiry $i',
        subtitle: 'Category: $category',
      ),
    );

    return PostScaffold(
      title: 'Rule Enquiries',
      leftPane: CategorySidebar(
        categories: categories,
        selectedKey: category,
        onSelect: (c) {
          context.go('/enquiries/$c'); // navigate on category change
        },
      ),
      centerPane: EnquiryList(
        header: const PaneHeader('Enquiries'),
        items: items,
        selectedId: enquiryId,
        onSelect: (id) {
          context.go('/enquiries/$category/$id'); // navigate on item select
        },
      ),
      rightPane: enquiryId == null
          ? null
          : EnquiryDetailPanel(enquiryId: enquiryId!),
    );
  }
}

class EnquiryDetailPanel extends StatelessWidget {
  const EnquiryDetailPanel({super.key, required this.enquiryId});

  final String enquiryId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enquiry $enquiryId',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'This is where the enquiry content will go. '
            'Later this can stream a Firestore doc.',
          ),
        ],
      ),
    );
  }
}
