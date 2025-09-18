import 'package:flutter/material.dart';

class TwoPaneShell extends StatelessWidget {
  const TwoPaneShell({
    super.key,
    required this.leftPane,
    required this.child,
    required this.breadcrumb,
  });

  final Widget leftPane;     // list at current level
  final Widget child;        // detail for current selection (or empty)
  final Widget breadcrumb;   // shows path

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Rule Enquiries')),
      body: Row(
        children: [
          SizedBox(
            width: 360, // responsive: shrink at < 1200px, hide on mobile
            child: leftPane,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                breadcrumb,
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
