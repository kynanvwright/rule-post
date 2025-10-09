import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

typedef ConfirmGuard = Future<bool> Function(BuildContext context);

class AdminAction {
  const AdminAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.enabled = true,
    this.confirmGuard, // if provided, used instead of the default dialog
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? tooltip;
  final bool enabled;
  final ConfirmGuard? confirmGuard;

  
  factory AdminAction.publishCompetitorResponses({
    required String enquiryId,
    required Future<int?> Function() run,
    required bool teamsCanRespond,
    required context,
  }) => AdminAction(
          label: 'Publish Competitor Responses',
          icon: Icons.publish,
          tooltip: teamsCanRespond ? 'Publish all submitted responses' : 'Locked: No pending responses',
          enabled: teamsCanRespond,
          onPressed: () async {
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
          // customise later, showing relevant info for action
          // confirmGuard: (ctx) async {
          //   return await showDialog<bool>(
          //     context: ctx,
          //     builder: (_) => AlertDialog(
          //       title: const Text('Are you sure?'),
          //       content: const Text('This will run the action immediately.'),
          //       actions: [
          //         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          //         FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
          //       ],
          //     ),
          //   ) ?? false;
          // }
        );

  factory AdminAction.publishRCResponse({
    required String enquiryId,
    required Future<bool> Function() run,
    required bool teamsCanRespond,
    required context,
  }) => AdminAction(
          label: 'Publish RC Response',
          icon: Icons.publish,
          tooltip: teamsCanRespond ? 'Locked: Wait for Competitors to respond' : 'Finish this enquiry stage and skip to the next',
          enabled: !teamsCanRespond,
          onPressed: () async {
            try {
              final functionSuccess = await run();
              if (functionSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Published RC response')),
                );
              }
            } on FormatException catch (e, st) {
              // Our validator: shows the exact path + type
              // e.g. "Invalid parameter at $.meta.stageEnds (Timestamp): Unsupported type..."
              // ignore: avoid_print
              print('Param validation failed: $e\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invalid parameters: ${e.message}')),
              );
            } on FirebaseFunctionsException catch (e, st) {
              // Server-side error from your callable
              // ignore: avoid_print
              print('Functions error: ${e.code} ${e.message}\nDetails: ${e.details}\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cloud Function error: ${e.code}: ${e.message ?? ''}')),
              );
            } catch (e, st) {
              // Client-side unexpected error (like the assert you saw)
              // ignore: avoid_print
              print('Unexpected error: $e\n$st');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unexpected error: $e')),
              );
            }
          },
          // customise later, showing relevant info for action
          // confirmGuard: (ctx) async {
          //   return await showDialog<bool>(
          //     context: ctx,
          //     builder: (_) => AlertDialog(
          //       title: const Text('Are you sure?'),
          //       content: const Text('This will run the action immediately.'),
          //       actions: [
          //         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          //         FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
          //       ],
          //     ),
          //   ) ?? false;
          // }
        );

  factory AdminAction.closeEnquiry({
    required String enquiryId,
    required Future<String?> Function() run,
    required context,
  }) => AdminAction(
          label: 'Close Enquiry',
          icon: Icons.lock,
          tooltip: 'End enquiry and lock all submissions',
          onPressed: () async {
            try {
              final closedEnquiryId = await run();
              if (closedEnquiryId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Enquiry closed')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to close enquiry')),
              );
            }
          },
          // // customise later, showing relevant info for action
          // confirmGuard: (ctx) async {
          //   return await showDialog<bool>(
          //     context: ctx,
          //     builder: (_) => AlertDialog(
          //       title: const Text('Are you sure?'),
          //       content: const Text('This will run the action immediately.'),
          //       actions: [
          //         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          //         FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
          //       ],
          //     ),
          //   ) ?? false;
          // }

        );
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

  Future<void> _confirmAndRun(BuildContext context) async {
    // If the button is disabled, do nothing
    if (!action.enabled) return;

    final ok = action.confirmGuard != null
      ? await action.confirmGuard!(context)
      : await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: Text(action.label),
            content: Text(
              (action.tooltip?.trim().isNotEmpty ?? false)
                  ? action.tooltip!.trim()
                  : "Are you sure you want to run “${action.label}”?",
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
        ) ?? false;

    if (ok) {
      action.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final btn = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minHeight,
      ),
      child: SizedBox(
        width: double.infinity, // full width in the column
        child: FilledButton.icon(
          onPressed: action.enabled ? () => _confirmAndRun(context) : null,
          icon: Icon(action.icon ?? Icons.settings),
          label: Text(action.label),
        ),
      ),
    );

    // Keep hover tooltip if provided (useful on desktop),
    // dialog still appears on click to guard the action.
    return (action.tooltip == null || action.tooltip!.isEmpty)
        ? btn
        : Tooltip(message: action.tooltip!, child: btn);
  }
}
