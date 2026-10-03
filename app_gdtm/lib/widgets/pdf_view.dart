// lib/widgets/pdf_view.dart
// Hiển thị PDF từ URL. Dùng Syncfusion trước; nếu lỗi:
//  - Web: chuyển sang trình xem dự phòng (Google viewer trong iframe), không cần pdf.js / CORS.
//  - Android / iOS: hiện thông báo lỗi + nút mở bằng trình duyệt.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:app_gdtm/widgets/attachment_utils.dart';

String googleViewerUrl(String url) =>
    'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';

class PdfView extends StatefulWidget {
  final String url;

  const PdfView({super.key, required this.url});

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  bool _failed = false;
  String? _reason;
  WebViewController? _web;

  void _onFailed(PdfDocumentLoadFailedDetails details) {
    if (!mounted || _failed) return;
    // Trình xem dự phòng chỉ có trên web và cần webview_flutter_web.
    // Nếu chưa cài thì bỏ qua (không để app bị lỗi), chỉ hiện thông báo.
    WebViewController? web;
    if (kIsWeb) {
      try {
        web = WebViewController()
          ..loadRequest(Uri.parse(googleViewerUrl(widget.url)));
      } catch (_) {
        web = null;
      }
    }
    setState(() {
      _failed = true;
      _reason = details.description;
      _web = web;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed) {
      return SfPdfViewer.network(
        widget.url,
        key: ValueKey(widget.url),
        onDocumentLoadFailed: _onFailed,
      );
    }

    // Trình xem dự phòng (web)
    if (_web != null) {
      return Column(children: [
        Container(
          color: const Color(0xFFFFF8E1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            const Expanded(
              child: Text('Đang dùng trình xem dự phòng',
                  style: TextStyle(fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => openUrl(context, widget.url),
              child: const Text('Mở tab mới'),
            ),
          ]),
        ),
        Expanded(child: WebViewWidget(controller: _web!)),
      ]);
    }

    // Không có trình xem dự phòng: báo lỗi
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.picture_as_pdf, size: 40, color: Colors.black38),
          const SizedBox(height: 8),
          const Text('Không mở được PDF', style: TextStyle(fontWeight: FontWeight.w600)),
          if (_reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_reason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openUrl(context, widget.url),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Mở bằng trình duyệt'),
          ),
        ]),
      ),
    );
  }
}