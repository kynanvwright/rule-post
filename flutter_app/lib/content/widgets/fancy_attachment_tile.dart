// flutter_app/lib/content/widgets/fancy_attachment_tile.dart
import 'dart:ui_web' as ui_web; // platformViewRegistry for web
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web; // DOM bindings (no dart:html)

import 'package:rule_post/debug/debug.dart';

/// Drop-in attachment tile that supports inline preview for PDFs and Word docs.
/// - PDFs (desktop web): try native PDF-in-iframe first, then fallback to Google Docs Viewer.
/// - Word docs: uses Google Docs Viewer.
/// - Mobile layout: uses Google Docs Viewer (usually more reliable).
///
/// Includes:
/// - Useful error messages for URL resolution failures and preview failures.
/// - Optional auto-collapse if preview fails.
class FancyAttachmentTile extends StatefulWidget {
  const FancyAttachmentTile({
    super.key,
    required this.name,
    this.url,
    this.path,
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
  factory FancyAttachmentTile.fromMap(
    Map<String, dynamic> m, {
    bool initialExpanded = false,
    double previewHeight = 420,
  }) {
    final dynamicSize = m['size'] ?? m['sizeBytes'];
    return FancyAttachmentTile(
      name: (m['name'] ?? m['fileName'] ?? 'file').toString(),
      url: (m['url'] ?? m['downloadUrl'])?.toString(),
      path: (m['path'])?.toString(),
      sizeBytes: dynamicSize is int ? dynamicSize : null,
      contentType: (m['contentType'] ?? m['mime'])?.toString(),
      initialExpanded: initialExpanded,
      previewHeight: previewHeight,
    );
  }

  final String name;
  final String? url;
  final String? path;
  final int? sizeBytes;
  final String? contentType;
  final bool initialExpanded;
  final double previewHeight;

  @override
  State<FancyAttachmentTile> createState() => _FancyAttachmentTileState();
}

class _FancyAttachmentTileState extends State<FancyAttachmentTile> {
  bool _expanded = false;
  String? _resolveError;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveUrl(),
      builder: (context, snap) {
        final resolvedUrl = snap.data ?? '';
        final hasUrl = resolvedUrl.isNotEmpty;

        final ct = (widget.contentType ?? '').toLowerCase();
        final ext = _ext(widget.name);
        final isPdf = _isPdf(ct, ext);
        final isWord = _isWord(ct, ext);
        final canPreviewInline = hasUrl && kIsWeb && (isPdf || isWord);
        final subtitle =
            (widget.sizeBytes != null) ? _fmtSize(widget.sizeBytes!) : '';

        // Loading state
        if (snap.connectionState == ConnectionState.waiting && !hasUrl) {
          return const ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading attachment…'),
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
          );
        }

        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(widget.name),
              subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: canPreviewInline
                        ? (_expanded ? 'Hide preview' : 'Show content')
                        : 'Open',
                    icon: Icon(
                      canPreviewInline
                          ? (_expanded
                              ? Icons.expand_less
                              : Icons.expand_more)
                          : Icons.open_in_new,
                    ),
                    onPressed: hasUrl
                        ? () {
                            if (canPreviewInline) {
                              setState(() => _expanded = !_expanded);
                            } else {
                              _openUrl(resolvedUrl);
                            }
                          }
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Download',
                    icon: const Icon(Icons.download),
                    onPressed: hasUrl ? () => _openUrl(resolvedUrl) : null,
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
                    url: resolvedUrl,
                    isPdf: isPdf,
                    isWord: isWord,
                    height: widget.previewHeight,

                    // Optional collapse behaviour:
                    collapseOnFailure: true,
                    onRequestCollapse: () {
                      if (!mounted) return;
                      setState(() => _expanded = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Preview failed — collapsed. Use Open/Download instead.',
                          ),
                        ),
                      );
                    },

                    // Pass timeouts to avoid "unused parameter" warnings and
                    // to make behaviour tunable.
                    nativePdfTimeout: const Duration(seconds: 4),
                    fallbackTimeout: const Duration(seconds: 10),
                  ),
                ),
              ),

            const Divider(height: 1),

            if (!hasUrl && snap.connectionState == ConnectionState.done)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const Text('Attachment unavailable'),
                  subtitle: Text(
                    _resolveError ?? 'No URL/path, or access denied.',
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(String link) async {
    final ok =
        await launchUrlString(link, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(kIsWeb ? 'Open in new tab:\n$link' : 'Open: $link'),
        ),
      );
    }
  }

  Future<String?> _resolveUrl() async {
    _resolveError = null;

    // 1) If a URL was provided, use it as-is
    final given = widget.url;
    if (given != null && given.isNotEmpty) return given;

    // 2) Otherwise, try to mint a URL from the Storage path
    final p = widget.path;
    if (p == null || p.isEmpty) {
      _resolveError = 'No url or storage path provided.';
      return null;
    }

    try {
      final ref = firebase_storage.FirebaseStorage.instance.ref(p);
      return await ref.getDownloadURL();
    } catch (e) {
      final msg = 'Failed to get download URL (access denied or missing file).';
      d('FancyAttachmentTile: $msg path=$p error=$e');
      _resolveError = '$msg\nPath: $p\nError: $e';
      return null;
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
/// - For PDF (desktop web): try native embed first, then fall back to Google Docs Viewer.
/// - For Word: uses Google Docs Viewer.
/// - For mobile layout: uses Google Docs Viewer (usually more reliable).
///
/// NOTE:
/// - Some hosts may block embedding with X-Frame-Options/CSP.
/// - Some browsers may silently download PDFs instead of rendering; this may not trigger iframe error.
///   We treat "no load within timeout" as failure and attempt fallback.
class _InlineDocIFrame extends StatefulWidget {
  const _InlineDocIFrame({
    required this.url,
    required this.isPdf,
    required this.isWord,
    this.height = 840,
    this.collapseOnFailure = false,
    this.onRequestCollapse,
    this.nativePdfTimeout = const Duration(seconds: 6),
    this.fallbackTimeout = const Duration(seconds: 10),
  });

  final String url;
  final bool isPdf;
  final bool isWord;
  final double height;

  /// If true, and all preview methods fail, ask the parent to collapse the preview.
  final bool collapseOnFailure;
  final VoidCallback? onRequestCollapse;

  /// Timeout for the native PDF attempt (desktop only).
  final Duration nativePdfTimeout;

  /// Timeout for the fallback attempt (Google Docs Viewer).
  final Duration fallbackTimeout;

  @override
  State<_InlineDocIFrame> createState() => _InlineDocIFrameState();
}

enum _PreviewMethod { nativePdf, googleDocs, direct }

class _InlineDocIFrameState extends State<_InlineDocIFrame> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;

  bool _registered = false;

  bool _loading = true;
  String? _errorMsg;

  _PreviewMethod? _method; // current method
  int _attempt = 0; // increments per load attempt (to ignore stale timers)

  bool _isMobileLayout(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    _viewType = 'iframe-${UniqueKey()}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registered) return;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final el = web.HTMLIFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';

      _iframe = el;

      el.onLoad.listen((_) {
        if (!mounted) return;
        d('InlineDocIFrame: onLoad method=${_method?.name} attempt=$_attempt');
        setState(() {
          _loading = false;
          _errorMsg = null;
        });
      });

      el.onError.listen((_) {
        // Note: may not fire for "download instead of render" cases.
        _handleAttemptFailure('iframe error event fired');
      });

      return el;
    });

    _registered = true;

    // Kick off initial load once iframe exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startInitialLoad();
    });
  }

  @override
  void didUpdateWidget(covariant _InlineDocIFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.isPdf != widget.isPdf ||
        oldWidget.isWord != widget.isWord) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startInitialLoad();
      });
    }
  }

  void _startInitialLoad() {
    final mobile = _isMobileLayout(context);

    // Word or mobile -> Google Docs Viewer
    if (widget.isWord || mobile) {
      _loadWith(_PreviewMethod.googleDocs, timeout: widget.fallbackTimeout);
      return;
    }

    // PDF desktop -> native first, then fallback if needed
    if (widget.isPdf && !mobile) {
      _loadWith(_PreviewMethod.nativePdf, timeout: widget.nativePdfTimeout);
      return;
    }

    // Anything else -> direct
    _loadWith(_PreviewMethod.direct, timeout: widget.fallbackTimeout);
  }

  String _srcFor(_PreviewMethod method) {
    switch (method) {
      case _PreviewMethod.nativePdf:
        return '${widget.url}#toolbar=1&navpanes=0&scrollbar=1';
      case _PreviewMethod.googleDocs:
        return 'https://docs.google.com/gview?url=${Uri.encodeComponent(widget.url)}&embedded=true';
      case _PreviewMethod.direct:
        return widget.url;
    }
  }

  void _loadWith(_PreviewMethod method, {required Duration timeout}) {
    final iframe = _iframe;
    if (iframe == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadWith(method, timeout: timeout);
      });
      return;
    }

    _attempt++;
    final thisAttempt = _attempt;

    setState(() {
      _method = method;
      _loading = true;
      _errorMsg = null;
    });

    final src = _srcFor(method);

    d('InlineDocIFrame: attempt=$_attempt method=${method.name} '
        'timeout=${timeout.inSeconds}s');
    d('InlineDocIFrame: src=$src');

    // Avoid an extra navigation for the initial/native PDF attempt; it can
    // increase flaky behaviour on some Chrome configs.
    if (method == _PreviewMethod.nativePdf) {
      iframe.src = src;
    } else {
      iframe.src = 'about:blank';
      Future.microtask(() => iframe.src = src);
    }

    final methodAtStart = method;

    Future.delayed(timeout, () {
      if (!mounted) return;
      if (_attempt != thisAttempt) return; // another load started
      if (_method != methodAtStart) return; // method changed
      if (!_loading) return; // already succeeded
      _handleAttemptFailure('timed out after ${timeout.inSeconds}s');
    });
  }

  void _handleAttemptFailure(String reason) {
    if (!mounted) return;

    d('InlineDocIFrame: FAILURE method=${_method?.name} attempt=$_attempt '
        'reason=$reason');

    final method = _method;
    final attemptedSrc = method == null ? null : _srcFor(method);

    // If native PDF failed, try Google Docs Viewer fallback.
    if (widget.isPdf && method == _PreviewMethod.nativePdf) {
      setState(() {
        _errorMsg =
            'Native PDF preview failed ($reason). Trying Google Docs Viewer…\n'
            'If this keeps happening, Chrome may be set to download PDFs instead of opening them.';
      });
      _loadWith(_PreviewMethod.googleDocs, timeout: widget.fallbackTimeout);
      return;
    }

    // If fallback failed (or direct failed), show error and optionally collapse.
    final msg = StringBuffer()
      ..writeln('Preview failed ($reason).')
      ..writeln()
      ..writeln('Tried: ${method?.name ?? 'unknown'}')
      ..writeln('Likely causes:')
      ..writeln('• Browser setting forces PDF download (Chrome: “Download PDFs”)')
      ..writeln('• Host blocks embedding (X-Frame-Options / CSP)')
      ..writeln('• Link requires auth/cookies not available to iframe')
      ..writeln()
      ..writeln('You can still use “Open” or “Download”.')
      ..writeln()
      ..writeln('URL:')
      ..writeln(attemptedSrc ?? widget.url);

    setState(() {
      _loading = false;
      _errorMsg = msg.toString();
    });

    if (widget.collapseOnFailure) {
      widget.onRequestCollapse?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel = switch (_method) {
      _PreviewMethod.nativePdf => 'PDF preview',
      _PreviewMethod.googleDocs => 'Google Docs Viewer',
      _PreviewMethod.direct => 'Inline preview',
      null => 'Preview',
    };

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(child: HtmlElementView(viewType: _viewType)),

          if (_loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.6),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 12),
                      Text('Loading $methodLabel…'),
                      const SizedBox(height: 6),
                      // if (_method == _PreviewMethod.nativePdf)
                      //   const Text('If it doesn’t load, we’ll auto-fallback.'),
                    ],
                  ),
                ),
              ),
            ),

          if (_errorMsg != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                elevation: 1,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
