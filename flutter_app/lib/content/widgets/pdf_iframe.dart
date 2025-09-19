import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web; // SDK-provided

class PdfIFrame extends StatefulWidget {
  const PdfIFrame({
    super.key,
    required this.src,
    this.height = 420,
    this.toolbar = true,
  });

  final String src;
  final double height;
  final bool toolbar;

  @override
  State<PdfIFrame> createState() => _PdfIFrameState();
}

class _PdfIFrameState extends State<PdfIFrame> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${UniqueKey()}';

    final url = widget.toolbar
        ? '${widget.src}#toolbar=1&navpanes=0&scrollbar=1'
        : widget.src;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = web.HTMLIFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
