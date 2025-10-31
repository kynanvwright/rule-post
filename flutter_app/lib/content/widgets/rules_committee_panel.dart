import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import './prompt_stage_length.dart';

typedef ConfirmGuard = Future<bool> Function(BuildContext context);
typedef ActionArgs = Object?;


class AdminAction {
  const AdminAction({
    required this.label,
    required this.runWithArgs,
    this.icon,
    this.tooltip,
    this.enabled = true,
    this.confirmGuard, // if provided, used instead of the default dialog
    this.buildAndGetArgs, // dialog/input step
  });

  final String label;
  final IconData? icon;
  final String? tooltip;
  final bool enabled;
  final ConfirmGuard? confirmGuard;  
  /// Step 1 (optional): show a dialog / sheet / form, gather user input,
  /// and return it. If this returns `null`, we treat that as "cancel".
  final Future<ActionArgs?> Function(BuildContext context)? buildAndGetArgs;
  /// Step 2: actually perform the action using those args.
  /// If `buildAndGetArgs` is null, we'll call this with `null`.
  final Future<void> Function(ActionArgs args) runWithArgs;

  factory AdminAction.publishCompetitorResponses({
    required String enquiryId,
    required Future<int?> Function() run,
    required bool enabled,
    required context,
  }) => AdminAction(
          label: 'Publish Competitor Responses',
          icon: Icons.publish,
          tooltip: enabled ? 'Publish all submitted responses' : 'Locked: No pending responses',
          enabled: enabled,
          runWithArgs: (_) async {
            try {
              final functionSuccess = await run();
              if (functionSuccess != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Published $functionSuccess Competitor responses')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to publish Competitor responses')),
              );
            }
          },
        );

  factory AdminAction.publishRCResponse({
    required String enquiryId,
    required Future<bool> Function() run,
    required bool enabled,
    required context,
  }) => AdminAction(
          label: 'Publish RC Response',
          icon: Icons.publish,
          tooltip: enabled ? 'Finish this enquiry stage and skip to the next' : 'Locked: Wait for Competitors to respond',
          enabled: enabled,
          runWithArgs: (_) async {
            try {
              final functionSuccess = await run();
              if (functionSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Published RC response')),
                );
              }
            } on FormatException catch (e, st) {
              debugPrint('Param validation failed: $e\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invalid parameters: ${e.message}')),
              );
            } on FirebaseFunctionsException catch (e, st) {
              debugPrint('Functions error: ${e.code} ${e.message}\nDetails: ${e.details}\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cloud Function error: ${e.code}: ${e.message ?? ''}')),
              );
            } catch (e, st) {
              debugPrint('Unexpected error: $e\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unexpected error: $e')),
              );
            }
          },
        );

  factory AdminAction.closeEnquiry({
    required String enquiryId,
    required Future<String?> Function(EnquiryConclusion t) run,
    required bool enabled,
    required BuildContext context,
  }) => AdminAction(
          label: 'Close Enquiry',
          icon: Icons.lock,
          tooltip: enabled ? 'End enquiry and lock all submissions' : 'Locked: Enquiry already closed',
          enabled: enabled,
          // Step 1: show dropdown dialog and return the chosen EnquiryConclusion (or null)
          buildAndGetArgs: (ctx) async {
            final chosen = await promptChooseOption<EnquiryConclusion>(
              context: ctx,
              title: 'Close enquiry?',
              message:
                  'Indicate how it ended:',
              confirmLabel: 'Proceed',
              items: const [
                DropdownMenuItem(
                  value: EnquiryConclusion.amendment,
                  child: Text('Amendment'),
                ),
                DropdownMenuItem(
                  value: EnquiryConclusion.interpretation,
                  child: Text('Interpretation'),
                ),
                DropdownMenuItem(
                  value: EnquiryConclusion.noResult,
                  child: Text('Enquiry closed with no interpretation or amendment.'),
                ),
              ],
            );
            // If user hit Cancel, `chosen` will be null.
            return chosen;
          },
          runWithArgs: (args) async {
            final enquiryConclusion = args as EnquiryConclusion?;
            if (enquiryConclusion == null) {
              // user cancelled / never selected
              return;
            }
            try {
              final closedEnquiryId = await run(enquiryConclusion);
              if (!context.mounted) return;
              if (closedEnquiryId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enquiry closed',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to close enquiry'),
                  ),
                );
              }
            } on FirebaseFunctionsException catch (e, st) {
              debugPrint(
                  'Functions error: ${e.code} ${e.message}\nDetails: ${e.details}\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cloud Function error: ${e.code}: ${e.message ?? ''}',
                  ),
                ),
              );
            } catch (e, st) {
              debugPrint('Unexpected error: $e\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unexpected error: $e')),
              );
            }
          },
        );
  factory AdminAction.changeStageLength({
    required String enquiryId,
    // Load the current value (e.g. read Firestore or call a CF)
    required Future<int> Function() loadCurrent,
    // Apply/save the new value (e.g. call a CF that writes and recomputes)
    required Future<bool> Function(int newDays) run,
    required bool enabled,
    required BuildContext context,
  }) {
    int? pendingDays;

    return AdminAction(
      label: 'Change Stage Length',
      icon: Icons.timer, // a little more descriptive than lock
      tooltip: enabled ? 'Change number of working days for major enquiry stages (default: 4)' : 'Locked: Enquiry closed',
      enabled: enabled,
      // Step 1: confirmGuard handles fetch + numeric input
      confirmGuard: (ctx) async {
        final v = await promptStageLength(ctx, loadCurrent: loadCurrent, min: 1, max: 30);
        pendingDays = v;
        return v != null; // only proceed if user confirmed
      },
      // Step 2: onPressed runs only when confirmGuard returned true
      runWithArgs: (_) async {
        try {
          final days = pendingDays!;
          final ok = await run(days);
          if (!context.mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stage length set to $days working day${days == 1 ? '' : 's'}')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No change applied')),
            );
          }
        } on FormatException catch (e, st) {
          debugPrint('Param validation failed: $e\n$st');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid parameters: ${e.message}')),
          );
        } on FirebaseFunctionsException catch (e, st) {
          debugPrint('Functions error: ${e.code} ${e.message}\nDetails: ${e.details}\n$st');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cloud Function error: ${e.code}: ${e.message ?? ''}')),
          );
        } catch (e, st) {
          debugPrint('Unexpected error: $e\n$st');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unexpected error: $e')),
          );
        } finally {
          pendingDays = null; // clear captured state
        }
      },
    );
  }
}


class AdminCard extends StatefulWidget {
  const AdminCard({
    super.key,
    this.title = 'Rules Committee Panel',
    required this.actions,
    this.initiallyExpanded = false,
    this.compact = false,
    this.buttonMinWidth = 140,
    this.buttonMinHeight = 40,
    this.titleColour,
    this.boldTitle = true,
  });

  final String title;
  final List<AdminAction> actions;
  final bool initiallyExpanded;

  final bool compact;
  final double buttonMinWidth;
  final double buttonMinHeight;
  final Color? titleColour;
  final bool boldTitle;

  @override
  State<AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<AdminCard> {
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    final titleStyle = base?.copyWith(
      color: widget.titleColour ?? base.color,
      fontWeight: widget.boldTitle ? FontWeight.bold : base.fontWeight,
    );

    final spacing = widget.compact ? 8.0 : 12.0;

    return Card(
      child: Theme( // Tighten ExpansionTile divider look
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          title: Text(widget.title, style: titleStyle),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            // Vertical list of guarded admin actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < widget.actions.length; i++) ...[
                  _GuardedActionButton(
                    action: widget.actions[i],
                    minWidth: widget.buttonMinWidth,
                    minHeight: widget.buttonMinHeight,
                  ),
                  if (i != widget.actions.length - 1)
                    SizedBox(height: spacing),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// A full-width button that shows a warning/confirmation dialog before running.
class _GuardedActionButton extends StatelessWidget {
  const _GuardedActionButton({
    required this.action,
    required this.minWidth,
    required this.minHeight,
  });

  final AdminAction action;
  final double minWidth;
  final double minHeight;

  Future<void> _handlePress(BuildContext context) async {
    if (!action.enabled) return;

    // 1. If there's a dialog/input step, run it.
    ActionArgs? args;
    if (action.buildAndGetArgs != null) {
      args = await action.buildAndGetArgs!(context);
      // User hit cancel
      if (args == null) return;
    } else {
      // 2. Otherwise show the stock "are you sure?" dialog.
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded),
              title: Text(action.label),
              content: Text(
                (action.tooltip?.trim().isNotEmpty ?? false)
                    ? action.tooltip!.trim()
                    : 'Are you sure you want to run “${action.label}”?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Proceed'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      args = null; // no custom data
    }

    // 3. Actually run the action with the gathered args.
    await action.runWithArgs(args);
  }

  @override
  Widget build(BuildContext context) {
    final btn = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minHeight,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: action.enabled ? () => _handlePress(context) : null,
          icon: Icon(action.icon ?? Icons.settings),
          label: Text(action.label),
        ),
      ),
    );

    return (action.tooltip == null || action.tooltip!.isEmpty)
        ? btn
        : Tooltip(message: action.tooltip!, child: btn);
  }
}


Future<T?> promptChooseOption<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<DropdownMenuItem<T>> items,
  required String confirmLabel,
}) async {
  T? tempValue;

  return showDialog<T>(
    context: context,
    barrierDismissible: false, // force explicit Cancel/Confirm
    builder: (ctx) {
      return AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (ctx, setState) {
                return DropdownButtonFormField<T>(
                  initialValue: tempValue,
                  items: items,
                  onChanged: (newVal) {
                    setState(() {
                      tempValue = newVal;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Select an option',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Only allow confirm if something is chosen
              if (tempValue != null) {
                Navigator.of(ctx).pop(tempValue);
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}


enum EnquiryConclusion { amendment, interpretation, noResult }