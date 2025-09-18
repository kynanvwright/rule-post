import 'package:flutter/material.dart';
import 'post_list_item.dart';
// import 'pane_header.dart';

class EnquiryList extends StatelessWidget {
  const EnquiryList({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    // this.header = const PaneHeader('Enquiries'),
    this.emptyMessage = 'No enquiries found',
  });

  final List<EnquiryListEntry> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  // final Widget header;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // header,
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return PostListItem(
                      id: e.id,
                      title: e.title,
                      subtitle: e.subtitle,
                      trailing: e.trailing,
                      selected: e.id == selectedId,
                      onTap: () => onSelect(e.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class EnquiryListEntry {
  EnquiryListEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Widget? trailing;
}
