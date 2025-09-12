import 'package:flutter/material.dart';

class CategorySidebar extends StatelessWidget {
  const CategorySidebar({
    super.key,
    required this.categories,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<(String key, String label)> categories;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        for (final (key, label) in categories)
          ListTile(
            dense: true,
            selected: key == selectedKey,
            title: Text(label),
            onTap: () => onSelect(key),
          ),
      ],
    );
  }
}
