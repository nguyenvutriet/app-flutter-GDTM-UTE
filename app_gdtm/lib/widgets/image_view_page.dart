import 'package:flutter/material.dart';

class ImageViewPage extends StatelessWidget {
  final String url;
  final String? fileName;

  const ImageViewPage({
    super.key,
    required this.url,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName ?? 'Xem ảnh',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const CircularProgressIndicator(
                color: Colors.white,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.white70,
                    size: 60,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Không thể hiển thị ảnh',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}