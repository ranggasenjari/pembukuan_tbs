import 'dart:typed_data';
import 'package:flutter/material.dart';

class ZoomableImagePreview extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;
  final double height;
  final double? width;

  const ZoomableImagePreview({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.height = 200,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null && imageUrl == null) return const SizedBox.shrink();

    final ImageProvider imageProvider = imageBytes != null
        ? MemoryImage(imageBytes!)
        : NetworkImage(imageUrl!) as ImageProvider;

    return GestureDetector(
      onTap: () => _showImageDetail(context, imageProvider),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
    );
  }

  void _showImageDetail(BuildContext context, ImageProvider imageProvider) {
    _showFullScreenImage(context, imageProvider);
  }

  static void showImageDialog(BuildContext context, {Uint8List? imageBytes, String? imageUrl}) {
    final ImageProvider provider = imageBytes != null
        ? MemoryImage(imageBytes)
        : NetworkImage(imageUrl!) as ImageProvider;
    _showFullScreenImage(context, provider);
  }

  static void _showFullScreenImage(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black54),
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image(image: imageProvider, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
