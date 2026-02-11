// flutter_app/lib/content/widgets/status_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


// A card showing the current enquiry stage, with start/end times and next stage info
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.stageMap,
  });
  final Map<String, dynamic> stageMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurfaceVariant;
    final dateStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
    );
    final stageTexts = _getStageTexts(stageMap);
    final startLocal = _asLocal(stageMap['stageStarts']);
    final endLocal   = _asLocal(stageMap['stageEnds']);

    final startStr = _fmt(startLocal);
    final endStr   = _fmt(endLocal);

    // Explain *which* zone we used (device-local). Show once.
    final ref = startLocal ?? endLocal;
    final tzInfo = ref == null
        ? ''
        : ' (${ref.timeZoneName}, UTC${_fmtTzOffset(ref.timeZoneOffset)})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stage title ────────────────────────────────
        Text(
          stageTexts[0],
          style: theme.textTheme.titleMedium?.copyWith(
            color: fg,
            // fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        // ── Start / End datetimes ──────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(Icons.schedule, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: 
                Text(
                  '$startStr  →  $endStr$tzInfo',
                  style: dateStyle,
                  overflow: TextOverflow.ellipsis,
                ),
            ),
          ],
        ),
        if (stageTexts[1] != '')... [
          const SizedBox(height: 8),
          // ── Next stage ─────────────────────────────────
          Row(
            children: [
              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 6),
              Text(
                'Next Stage: ${stageTexts[1]}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ],
    ); 
  }
  
  List<String>_getStageTexts(Map<String, dynamic> stageMap) {
    // return current and next stage descriptions
    if (stageMap['isOpen'] == false) {
      return ['',''];
    // } else if (stageMap['isPublished'] == false) {
    //   return ['Unpublished','Competitors may respond'];
    } else if (stageMap['teamsCanRespond']) {
      return ['Competitors may respond','Competitors may comment on responses'];
    } else if (stageMap['teamsCanComment']) {
      return ['Competitors may comment on responses','Rules Committee review'];
    } else {
      return ['Under Rules Committee review',''];
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    // Show in local time with short readable format
    return '${dt.day.toString().padLeft(2, '0')} '
        '${_month(dt.month)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }

  DateTime? _asLocal(dynamic v) {
    if (v == null) return null;

    DateTime asUtc;
    if (v is DateTime) {
      asUtc = v.isUtc ? v : v.toUtc();
    } else if (v is Timestamp) {
      asUtc = v.toDate().toUtc();
    } else if (v is int) {
      asUtc = DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    } else if (v is String) {
      asUtc = DateTime.parse(v).toUtc(); // expects ISO-8601
    } else {
      throw ArgumentError('Unsupported date type: ${v.runtimeType}');
    }
    return asUtc.toLocal(); // ← device/browser local time zone
  }

  String _fmtTzOffset(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final h = d.inHours.abs().toString().padLeft(2, '0');
    final m = (d.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }
}