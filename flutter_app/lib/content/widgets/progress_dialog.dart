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
  List<String> steps = const ['Checking user authentication…','Preparing data…','Saving to database…'],
  Duration stepInterval = const Duration(seconds: 2),

  // NEW: optional builder for dynamic success text
  String Function(T result)? successBuilder,
  String successTitle = 'All done',
  String successMessage = 'Your action completed successfully.',
  String Function(T result)? failureBuilder,
  String failureTitle = 'Something went wrong',
  String failureMessage = 'Please try again.',
  bool barrierDismissibleWhileRunning = false,
  bool autoCloseOnSuccess = true,
  Duration autoCloseAfter = const Duration(seconds: 3, milliseconds: 500),
}) async {
  assert(steps.isNotEmpty);

  final completer = Completer<T>();
  late StateSetter statesetter;
  int stepIndex = 0;
  bool running = true;
  String currentText = steps.first;
  Timer? ticker;
  Object? error;

  // NEW: hold the computed success text (after action resolves)
  String? computedSuccessText;
  String? computedFailureText;

  showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissibleWhileRunning == true ? true : false,
    builder: (ctx) {
      return PopScope(
        canPop: !running && barrierDismissibleWhileRunning,
        onPopInvokedWithResult: (didPop, result) {},
        child: StatefulBuilder(
          builder: (ctx, setState) {
            statesetter = setState;
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Row(
                children: [
                  if (running)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  else if (error == null)
                    const Icon(Icons.check_circle, size: 20)
                  else
                    const Icon(Icons.error_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(running ? 'Working…' : (error == null ? successTitle : failureTitle)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      running
                          ? currentText
                          : (error == null
                              ? (computedSuccessText ?? successMessage)
                              : computedFailureText ?? failureMessage),
                      key: ValueKey('${running}_${currentText}_${error != null}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              actions: [
                if (!running)
                  TextButton(
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

  void startTicker() {
    ticker?.cancel();
    ticker = Timer.periodic(stepInterval, (_) {
      if (!running) return;
      stepIndex = (stepIndex + 1) % steps.length;
      currentText = steps[stepIndex];
      statesetter(() {});
    });
  }

  startTicker();

  // Run the action
  () async {
    try {
      final res = await action();

      // NEW: compute success text once we have the result
      computedSuccessText = successBuilder != null ? successBuilder(res) : null;
      computedFailureText = failureBuilder != null ? failureBuilder(res) : null;

      running = false;
      ticker?.cancel();
      statesetter(() {}); // re-render with computedSuccessText

      if (autoCloseOnSuccess) {
        await Future.delayed(autoCloseAfter);
        if (!context.mounted) return;
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
      if (!completer.isCompleted) completer.complete(res);
    } catch (e, st) {
      running = false;
      ticker?.cancel();
      error = e;
      statesetter(() {});
      if (!completer.isCompleted) completer.completeError(e, st);
    }
  }();

  return completer.future;
}
