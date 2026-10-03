// lib/widgets/pdf_view.dart
// Hiển thị PDF từ URL. Dùng Syncfusion trước; nếu lỗi:
//  - Web: chuyển sang trình xem dự phòng bằng iframe native.
//  - Android / iOS: hiện thông báo lỗi + nút mở bằng trình duyệt.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_web_view_stub.dart'
    if (dart.library.html) 'package:app_gdtm/widgets/pdf_web_view_web.dart';

class PdfView extends StatefulWidget {
  final String url;

  const PdfView({super.key, required this.url});

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  bool _failed = false;
  String? _reason;

  void _onFailed(PdfDocumentLoadFailedDetails details) {
    if (!mounted || _failed) return;
    setState(() {
      _failed = true;
      _reason = details.description;
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

    // Trình xem dự phòng trên web dùng iframe native, không phụ thuộc
    // webview_flutter và không cần Google Docs Viewer.
    if (kIsWeb) {
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
        Expanded(child: PdfWebView(url: widget.url)),
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