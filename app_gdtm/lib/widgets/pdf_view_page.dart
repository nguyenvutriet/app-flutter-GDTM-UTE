import 'package:flutter/material.dart';
import 'pdf_view.dart';

class PdfViewPage extends StatelessWidget {
  final String url;
  final String? fileName;

  const PdfViewPage({
    super.key,
    required this.url,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName ?? 'Xem PDF',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PdfView(url: url),
    );
  }
}