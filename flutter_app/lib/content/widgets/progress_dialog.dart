import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a progress dialog that:
///  - cycles through [steps] every [stepInterval]
///  - awaits [action]
///  - then shows success/failure message
/// Returns the action's value if successful, otherwise rethrows.
Future<T> showProgressFlow<T>({
  required BuildContext context,
  required Future<T> Function() action,
  List<String> steps = const [
    'Checking user authentication…',
    'Preparing data…',
    'Saving to database…',
  ],
  Duration stepInterval = const Duration(seconds: 2),
  String successTitle = 'All done',
  String successMessage = 'Your action completed successfully.',
  String failureTitle = 'Something went wrong',
  String failureMessage = 'Please try again.',
  bool barrierDismissibleWhileRunning = false,
  bool autoCloseOnSuccess = true,
  Duration autoCloseAfter = const Duration(seconds: 3, milliseconds: 500),
}) async {
  assert(steps.isNotEmpty);

  final completer = Completer<T>();
  late StateSetter _setState;
  int stepIndex = 0;
  bool running = true;
  String currentText = steps.first;
  Timer? ticker;
  Object? error;
  StackTrace? stack;

  // Open dialog
  // Use StatefulBuilder so we can mutate the inner UI from this function.
  showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissibleWhileRunning == true ? true : false,
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async => !running && barrierDismissibleWhileRunning,
        child: StatefulBuilder(
          builder: (ctx, setState) {
            _setState = setState;
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Row(
                children: [
                  if (running) const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5),
                  ) else if (error == null) const Icon(Icons.check_circle, size: 20)
                  else const Icon(Icons.error_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(running
                      ? 'Working…'
                      : (error == null ? successTitle : failureTitle)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      running ? currentText
                             : (error == null ? successMessage : failureMessage),
                      key: ValueKey('${running}_${currentText}_${error != null}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              actions: [
                if (!running) TextButton(
                  onPressed: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  // Rotate interim step text
  void startTicker() {
    ticker?.cancel();
    ticker = Timer.periodic(stepInterval, (_) {
      if (!running) return;
      stepIndex = (stepIndex + 1) % steps.length;
      currentText = steps[stepIndex];
      _setState(() {});
    });
  }

  startTicker();

  // Run the action
  // When it resolves, flip UI to final state and close (optionally) after a delay.
  () async {
    try {
      final res = await action();
      running = false;
      ticker?.cancel();
      _setState(() {});
      if (autoCloseOnSuccess) {
        await Future.delayed(autoCloseAfter);
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
      if (!completer.isCompleted) completer.complete(res);
    } catch (e, st) {
      running = false;
      ticker?.cancel();
      error = e; stack = st;
      _setState(() {});
      // Keep dialog open until user closes (so they can see the error).
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  }();

  return completer.future;
}
