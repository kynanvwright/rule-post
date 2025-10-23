// flutter_app/lib/content/screens/no_selection_page.dart
import 'package:flutter/material.dart';

/// -------------------- NO SELECTION --------------------
class NoSelectionPage extends StatelessWidget {
  const NoSelectionPage({super.key, this.message = 'Select an item to view details.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}