import 'package:flutter/material.dart';
import 'package:flutter_app/core/widgets/app_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher_string.dart';


import '../../core/widgets/post_scaffold.dart';
import '../../core/widgets/category_sidebar.dart';
import '../../core/widgets/post_list.dart';
import '../../core/widgets/pane_header.dart';
import '../widgets/new_post_button.dart';

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
      ('open', 'Open'),
      ('closed', 'Closed'),
    ];

    Query<Map<String, dynamic>> listQuery = FirebaseFirestore.instance
        .collection('enquiries');

    // Filter by category (only "all" works today unless you've denormalized fields)
    switch (category) {
      case 'all':
        // no where-clause
        break;

      case 'open':
        listQuery = listQuery.where('isOpen', isEqualTo: true);
        break;

      case 'closed':
        listQuery = listQuery.where('isOpen', isEqualTo: false);
        break;
      
      // case 'unpublished drafts':
      //   // Example below, actually needs more filters
      //   // Requires authorUid on each 'enquiries' doc (denormalize from enquiries_meta)
      //   // final uid = FirebaseAuth.instance.currentUser?.uid;
      //   // if (uid != null) listQuery = listQuery.where('authorUid', isEqualTo: uid);
      //   break;
    }

    listQuery = listQuery.orderBy('createdAt', descending: true).limit(50);


    return AppScaffold(
      title: 'Rule Enquiries',
      child: PostScaffold(
        title: 'Rule Enquiries',
        leftPane: CategorySidebar(
          categories: categories,
          selectedKey: category,
          onSelect: (c) {
            context.replace('/enquiries/$c'); // navigate on category change
          },
        ),
        // centerPane: EnquiryList(
        //   header: const PaneHeader('Enquiries'),
        //   items: items,
        //   selectedId: enquiryId,
        //   onSelect: (id) {
        //     context.go('/enquiries/$category/$id'); // navigate on item select
        //   },
        // ),
        centerPane: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: listQuery.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Failed to load enquiries'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No enquiries yet'));
            }

            // Map Firestore docs -> your list row model
            final liveItems = docs.map((d) {
              final data = d.data();
              final title = (data['titleText'] ?? '').toString();
              final enquiryNumber = (data['enquiryNumber'] ?? 'Unnumbered').toString();
              final enquiryNumberString = 'Rule Enquiry #$enquiryNumber';

              return EnquiryListEntry(
                id: d.id,
                title: title.isEmpty ? '(untitled)' : title,
                subtitle: enquiryNumberString,
              );
            }).toList();

            return EnquiryList(
              header: const PaneHeader('Enquiries',
              trailing: NewEnquiryButton()),
              items: liveItems,
              selectedId: enquiryId,
              onSelect: (id) => context.go('/enquiries/$category/$id'),
            );
          },
        ),
        rightPane: enquiryId == null
            ? null
            : EnquiryDetailPanel(
              enquiryId: enquiryId!),
        ),
      );
  }
}

class EnquiryDetailPanel extends StatelessWidget {
  const EnquiryDetailPanel({super.key, required this.enquiryId});

  final String enquiryId;

  @override
  Widget build(BuildContext context) {
    final docRef =
        FirebaseFirestore.instance.collection('enquiries').doc(enquiryId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load enquiry'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final doc = snap.data!;
        if (!doc.exists) {
          return const Center(child: Text('Enquiry not found'));
        }

        final data = doc.data()!;
        final title = (data['titleText'] ?? '').toString();
        final body = (data['enquiryText'] ?? '').toString();

        DateTime? createdAt;
        final ts = data['createdAt'];
        if (ts is Timestamp) createdAt = ts.toDate();

        final attachments = (data['attachments'] is List)
            ? List<Map<String, dynamic>>.from(data['attachments'] as List)
            : const <Map<String, dynamic>>[];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(
                title.isEmpty ? '(untitled)' : title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Created ${_formatDate(createdAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              SelectableText(body.isEmpty ? '(no content)' : body),

              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Attachments',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...attachments.map((a) {
                  final name = (a['name'] ?? '').toString();
                  final url = (a['url'] ?? '').toString();
                  final size = a['size'];
                  final sizeLabel = size is num ? _formatBytes(size.toInt()) : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.attach_file),
                    title: Text(name.isEmpty ? 'Attachment' : name),
                    subtitle: sizeLabel == null ? null : Text(sizeLabel),
                    onTap: url.isEmpty
                        ? null
                        : () => launchUrlString(
                              url,
                              mode: LaunchMode.externalApplication,
                            ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime dt) {
    // Simple readable format; swap to intl if you want localization
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final fixed = size >= 10 || unit == 0 ? 0 : 1;
    return '${size.toStringAsFixed(fixed)} ${units[unit]}';
  }
}

