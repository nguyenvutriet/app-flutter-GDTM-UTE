import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _nextViewId = 0;

class PdfWebView extends StatefulWidget {
  final String url;

  const PdfWebView({super.key, required this.url});

  @override
  State<PdfWebView> createState() => _PdfWebViewState();
}

class _PdfWebViewState extends State<PdfWebView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-view-${_nextViewId++}';
    final frame = web.HTMLIFrameElement()
      ..src = widget.url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('title', 'Trình xem PDF');
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => frame,
    );
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
