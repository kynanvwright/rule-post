import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/new_post_button.dart';

/// -------------------- NO SELECTION --------------------
class NoSelectionPage extends StatelessWidget {
  const NoSelectionPage({super.key, this.message = 'Select an item to view details.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

/// -------------------- ENQUIRY DETAIL --------------------
class EnquiryDetailPage extends StatelessWidget {
  const EnquiryDetailPage({super.key, required this.enquiryId});
  final String enquiryId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load enquiry'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data();
        if (data == null) {
          return const Center(child: Text('Enquiry not found'));
        }

        final title = (data['title'] ?? 'Untitled Enquiry').toString();
        final number = (data['enquiryNumber'] ?? '–').toString();
        final isOpen = data['isOpen'] == true;
        final isPublished = data['isPublished'] == true;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final postText = (data['postText'] ?? '').toString();
        final attachments = (data['attachments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        return _DetailScaffold(
          header: 'Rule Enquiry #$number: $title',
          meta: MetaChips(
            chips: [
              Chip(label: Text(isOpen ? 'Open' : 'Closed')),
              if (!isPublished) const Chip(label: Text('Draft')),
              if (createdAt != null) Chip(label: Text(_fmtDateTime(createdAt))),
            ],
          ),
          body: postText.isNotEmpty
              ? Text(postText)
              : const Text('No enquiry text.'),
          attachments: attachments.map((m) => AttachmentTile.fromMap(m)).toList(),
          footer: Align(
            alignment: Alignment.centerLeft,
            child: NewPostButton(
              type: PostType.response,
              parentIds: [enquiryId]),
            ),
          trailingActions: [
            FilledButton.icon(
              onPressed: () => context.go('/enquiries/$enquiryId/responses'),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('View Responses'),
            ),
          ],
        );
      },
    );
  }
}

/// -------------------- RESPONSE DETAIL --------------------
class ResponseDetailPage extends StatelessWidget {
  const ResponseDetailPage({
    super.key,
    required this.enquiryId,
    required this.responseId,
  });

  final String enquiryId;
  final String responseId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load response'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data();
        if (data == null) {
          return const Center(child: Text('Response not found'));
        }

        final title = (data['titleText'] ?? 'Response').toString();
        final author = (data['authorName'] ?? 'Unknown').toString();
        final responseNumber = (data['responseNumber'] ?? '').toString();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final text = (data['postText'] ?? '').toString();
        final attachments = (data['attachments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        return _DetailScaffold(
          header: responseNumber.isNotEmpty ? 'Response $responseNumber: $title' : title,
          meta: MetaChips(
            chips: [
              Chip(label: Text(author)),
              if (createdAt != null) Chip(label: Text(_fmtDateTime(createdAt))),
            ],
          ),
          body: text.isNotEmpty ? Text(text) : const Text('No response text.'),
          attachments: attachments.map((m) => AttachmentTile.fromMap(m)).toList(),
          trailingActions: [
            FilledButton.icon(
              onPressed: () => context.go('/enquiries/$enquiryId/responses/$responseId/comments'),
              icon: const Icon(Icons.mode_comment_outlined),
              label: const Text('View Comments'),
            ),
          ],
        );
      },
    );
  }
}

/// -------------------- COMMENT DETAIL --------------------
class CommentDetailPage extends StatelessWidget {
  const CommentDetailPage({
    super.key,
    required this.enquiryId,
    required this.responseId,
    required this.commentId,
  });

  final String enquiryId;
  final String responseId;
  final String commentId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('enquiries')
        .doc(enquiryId)
        .collection('responses')
        .doc(responseId)
        .collection('comments')
        .doc(commentId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data() ?? {},
          toFirestore: (v, _) => v,
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Failed to load comment'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data();
        if (data == null) {
          return const Center(child: Text('Comment not found'));
        }

        final author = (data['authorName'] ?? 'Unknown').toString();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final text = (data['text'] ?? data['postText'] ?? '').toString();
        final attachments = (data['attachments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        return _DetailScaffold(
          header: 'Comment',
          meta: MetaChips(
            chips: [
              Chip(label: Text(author)),
              if (createdAt != null) Chip(label: Text(_fmtDateTime(createdAt))),
            ],
          ),
          body: text.isNotEmpty ? Text(text) : const Text('No comment text.'),
          attachments: attachments.map((m) => AttachmentTile.fromMap(m)).toList(),
        );
      },
    );
  }
}

/// -------------------- SHARED DETAIL SCAFFOLD --------------------
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.header,
    required this.meta,
    required this.body,
    this.attachments = const <Widget>[],
    this.trailingActions = const <Widget>[],
    this.footer, // NEW
  });

  final String header;
  final Widget meta;
  final Widget body;
  final List<Widget> attachments;
  final List<Widget> trailingActions;
  final Widget? footer; // NEW

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(header, style: Theme.of(context).textTheme.titleLarge)),
              Wrap(spacing: 8, runSpacing: 8, children: trailingActions),
            ],
          ),
          const SizedBox(height: 8),
          meta,
          const Divider(height: 24),
          body,
          const SizedBox(height: 16),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...attachments,
          ],
          if (footer != null) ...[
            const Divider(height: 32),
            SafeArea(top: false, child: footer!), // keeps off nav bars
          ],
        ],
      ),
    );
  }
}


/// -------------------- META CHIPS ROW --------------------
class MetaChips extends StatelessWidget {
  const MetaChips({super.key, required this.chips});
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: -8,
      children: chips,
    );
  }
}

/// -------------------- ATTACHMENT TILE --------------------
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.name,
    this.url,
    this.sizeBytes,
    this.contentType,
  });

  final String name;
  final String? url;
  final int? sizeBytes;
  final String? contentType;

  factory AttachmentTile.fromMap(Map<String, dynamic> m) {
    return AttachmentTile(
      name: (m['name'] ?? m['fileName'] ?? 'file').toString(),
      url: (m['url'] ?? m['downloadUrl'])?.toString(),
      sizeBytes: (m['size'] ?? m['sizeBytes']) is int ? (m['size'] ?? m['sizeBytes']) as int : null,
      contentType: (m['contentType'] ?? m['mime'])?.toString(),
    );
    // Adjust keys to match your actual attachment model if different.
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (contentType != null) subtitleParts.add(contentType!);
    if (sizeBytes != null) subtitleParts.add(_fmtSize(sizeBytes!));
    final subtitle = subtitleParts.join(' • ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attachment),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: url != null
          ? IconButton(
              tooltip: 'Open',
              onPressed: () => _openLink(context, url!),
              icon: const Icon(Icons.open_in_new),
            )
          : null,
    );
  }

  void _openLink(BuildContext context, String url) {
    // You can plug in url_launcher or a custom viewer.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open: $url')),
    );
  }
}

/// -------------------- SMALL UTILS --------------------
String _fmtDateTime(DateTime dt) {
  // Simple readable format; replace with intl if you like.
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
}

String _fmtSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var b = bytes.toDouble();
  var i = 0;
  while (b >= 1024 && i < units.length - 1) {
    b /= 1024;
    i++;
  }
  return '${b.toStringAsFixed(b < 10 && i > 0 ? 1 : 0)} ${units[i]}';
}

String _two(int n) => n.toString().padLeft(2, '0');
