import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;      // DOM bindings (no dart:html)
import 'dart:ui_web' as ui_web;           // platformViewRegistry for web

/// Drop-in attachment tile that supports inline preview for PDFs and Word docs.
/// - PDFs render directly in an <iframe>.
/// - Word docs render via Google Docs Viewer (gview?embedded=true).
///
/// Usage:
///   FancyAttachmentTile.fromMap(doc['attachment'])
/// or
///   FancyAttachmentTile(name: ..., url: ..., contentType: ...);
class FancyAttachmentTile extends StatefulWidget {
  const FancyAttachmentTile({
    super.key,
    required this.name,
    this.url,
    this.sizeBytes,
    this.contentType,
    this.initialExpanded = false,
    this.previewHeight = 420,
  });

  /// Accepts both old/new shapes:
  /// - name/fileName
  /// - url/downloadUrl
  /// - size/sizeBytes
  /// - contentType/mime
  factory FancyAttachmentTile.fromMap(Map<String, dynamic> m,
      {bool initialExpanded = false, double previewHeight = 420}) {
    final dynamicSize = m['size'] ?? m['sizeBytes'];
    return FancyAttachmentTile(
      name: (m['name'] ?? m['fileName'] ?? 'file').toString(),
      url: (m['url'] ?? m['downloadUrl'])?.toString(),
      sizeBytes: dynamicSize is int ? dynamicSize : null,
      contentType: (m['contentType'] ?? m['mime'])?.toString(),
      initialExpanded: initialExpanded,
      previewHeight: previewHeight,
    );
  }

  final String name;
  final String? url;
  final int? sizeBytes;
  final String? contentType;
  final bool initialExpanded;
  final double previewHeight;

  @override
  State<FancyAttachmentTile> createState() => _FancyAttachmentTileState();
}

class _FancyAttachmentTileState extends State<FancyAttachmentTile> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.url != null && widget.url!.isNotEmpty;
    final ct = (widget.contentType ?? '').toLowerCase();
    final ext = _ext(widget.name);
    final isPdf = _isPdf(ct, ext);
    final isWord = _isWord(ct, ext);
    final canPreviewInline = hasUrl && kIsWeb && (isPdf || isWord);

    final meta = <String>[];
    if (ct.isNotEmpty) meta.add(ct);
    if (widget.sizeBytes != null) meta.add(_fmtSize(widget.sizeBytes!));
    final subtitle = meta.join(' • ');

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.attach_file),
          title: Text(widget.name, overflow: TextOverflow.ellipsis),
          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download),
                onPressed: hasUrl ? () => _openUrl(widget.url!) : null,
              ),
              IconButton(
                tooltip: canPreviewInline
                    ? (_expanded ? 'Hide preview' : 'Show preview')
                    : 'Open',
                icon: Icon(canPreviewInline
                    ? (_expanded ? Icons.expand_less : Icons.expand_more)
                    : Icons.open_in_new),
                onPressed: hasUrl
                    ? () {
                        if (canPreviewInline) {
                          setState(() => _expanded = !_expanded);
                        } else {
                          _openUrl(widget.url!);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
        if (_expanded && canPreviewInline)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _InlineDocIFrame(
                url: widget.url!,
                isPdf: isPdf,
                isWord: isWord,
                height: widget.previewHeight,
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _openUrl(String link) async {
    final ok = await launchUrlString(link, mode: LaunchMode.externalApplication);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kIsWeb ? 'Open in new tab:\n$link' : 'Open: $link')),
      );
    }
  }
}

/// Returns file extension (lowercase) including the dot, or empty string.
String _ext(String name) {
  final i = name.lastIndexOf('.');
  return (i >= 0) ? name.substring(i).toLowerCase() : '';
}

bool _isPdf(String contentType, String ext) {
  return contentType == 'application/pdf' || ext == '.pdf';
}

bool _isWord(String contentType, String ext) {
  return contentType == 'application/msword' ||
      contentType ==
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
      ext == '.doc' ||
      ext == '.docx';
}

/// Simple bytes → human string.
String _fmtSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 && i > 0 ? 1 : 0)} ${units[i]}';
}

/// Inline document preview using an <iframe>.
/// - For PDF: embeds the PDF URL directly (browser PDF viewer).
/// - For Word: uses Google Docs Viewer to render inline.
///
/// NOTE: Some hosts may block embedding with X-Frame-Options/CSP.
/// If your storage host blocks embedding, fall back to "Open in new tab".
class _InlineDocIFrame extends StatelessWidget {
  const _InlineDocIFrame({
    required this.url,
    required this.isPdf,
    required this.isWord,
    this.height = 840,
  });

  final String url;
  final bool isPdf;
  final bool isWord;
  final double height;

  @override
  Widget build(BuildContext context) {
    final viewType = 'iframe-${UniqueKey()}';

    // check if device is a phone
    bool isMobileLayout(BuildContext context) =>
    MediaQuery.of(context).size.width < 600;
    
    // Choose iframe src:
    //  - PDF: open directly; add small viewer params
    //  - Word: use Google Docs Viewer to embed
    final src = isPdf & !isMobileLayout(context)
        ? '$url#toolbar=1&navpanes=0&scrollbar=1'
        : isWord || isMobileLayout(context)
            ? 'https://docs.google.com/gview?url=${Uri.encodeComponent(url)}&embedded=true'
            : url;

    // Register a one-off factory that returns an HTMLIFrameElement.
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = web.HTMLIFrameElement()
        ..src = src
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return el;
    });

    return SizedBox(
      height: height,
      child: HtmlElementView(viewType: viewType),
    );
  }
}
