// flutter_app/lib/content/widgets/custom_progress_indicator.dart
import 'dart:async';
import 'package:flutter/material.dart';


class RotatingProgressIndicator extends StatefulWidget {
  const RotatingProgressIndicator({super.key, this.messages, this.interval = const Duration(seconds: 10)});

  final List<String>? messages;
  final Duration interval;

  @override
  State<RotatingProgressIndicator> createState() => _RotatingProgressIndicatorState();
}

class _RotatingProgressIndicatorState extends State<RotatingProgressIndicator> {
  late final List<String> _messages;
  int _index = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _messages = widget.messages ??
        [
          'Preparing upload...',
          'Checking file size and format...',
          'Running test upload...',
          'Checking user permissions...',
        ];
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() => _index = (_index + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _messages[_index],
            key: ValueKey(_messages[_index]),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}