import 'package:flutter/material.dart';


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
