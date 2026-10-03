// lib/widgets/pdf_viewer_page.dart
// Xem PDF toàn màn hình.
import 'package:flutter/material.dart';

import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:app_gdtm/widgets/attachment_utils.dart';
import 'package:app_gdtm/widgets/pdf_view.dart';

class PdfViewerPage extends StatelessWidget {
  final String url;
  final String title;

  const PdfViewerPage({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Tải về',
            icon: const Icon(Icons.download),
            onPressed: () => openUrl(context, url),
          ),
        ],
      ),
      body: PdfView(url: url),
    );
  }
}