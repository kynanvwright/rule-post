import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;      // DOM bindings (no dart:html)
import 'dart:ui_web' as ui_web;           // platformViewRegistry for web
import 'dart:async'; // for Timer


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
class _InlineDocIFrame extends StatefulWidget {
  const _InlineDocIFrame({
    required this.url,
    required this.isPdf,
    required this.isWord,
    this.height = 840,
    this.timeoutMs = 2000, // how long we wait before falling back
  });

  final String url;
  final bool isPdf;
  final bool isWord;
  final double height;
  final int timeoutMs;

  @override
  State<_InlineDocIFrame> createState() => _InlineDocIFrameState();
}

class _InlineDocIFrameState extends State<_InlineDocIFrame> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  bool _loaded = false;
  bool _failed = false;
  bool _triedFallback = false;

  Timer? _watchdog; // <- add

  @override
  void initState() {
    super.initState();

    _viewType = 'iframe-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    final initialSrc = widget.isPdf
        ? '${widget.url}#toolbar=1&navpanes=0&scrollbar=1'
        : widget.isWord
            ? 'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.url)}&embedded=true'
            : widget.url;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final el = web.HTMLIFrameElement()
        ..src = initialSrc
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '8px'
        ..allow = 'fullscreen';

      el.onLoad.listen((_) {
        _loaded = true;
        _watchdog?.cancel();          // <- cancel watchdog
        if (mounted) setState(() {});
      });

      el.onError.listen((_) {
        _failed = true;
        _watchdog?.cancel();          // <- cancel watchdog
        if (mounted) setState(() {});
        _maybeFallback();
      });

      // Watchdog: if no load within X ms, fallback.
      _watchdog = Timer(Duration(milliseconds: widget.timeoutMs), () {  // <- replace setTimeout
        if (!_loaded && !_failed) {
          _maybeFallback();
        }
      });

      _iframe = el;
      return el;
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel(); // <- be tidy
    super.dispose();
  }

  void _maybeFallback() {
    if (_triedFallback) return;
    _triedFallback = true;

    if (widget.isPdf && _iframe != null) {
      final fallback = 'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.url)}&embedded=true';
      _iframe!.src = fallback;
    } else {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && !_loaded) {
      return _IFrameFallbackPanel(url: widget.url, height: widget.height);
    }
    return SizedBox(height: widget.height, child: HtmlElementView(viewType: _viewType));
  }
}

class _IFrameFallbackPanel extends StatelessWidget {
  const _IFrameFallbackPanel({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf, size: 28),
          const SizedBox(height: 8),
          const Text('Preview unavailable.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in new tab'),
            onPressed: () => launchUrlString(url, mode: LaunchMode.platformDefault),
          ),
        ],
      ),
    );
  }
}
