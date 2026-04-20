import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../utils/image_storage.dart';

/// フルスクリーン画像ビューア（Phase 10）
///
/// - 複数画像を PageView で横スワイプ
/// - 各画像は InteractiveViewer でピンチズーム可能
/// - 背景は黒、上部に「閉じる」ボタン、下部に 1/N インジケータ
/// - タップで閉じる/UI トグル、下スワイプ相当は閉じるボタンで対応
class ImageViewer extends StatefulWidget {
  final List<MemoImage> images;
  final int initialIndex;

  const ImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  /// ビューアを開くヘルパー（Navigator.push を呼び出すだけ）
  static Future<void> open(
    BuildContext context, {
    required List<MemoImage> images,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            ImageViewer(images: images, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showUi = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showUi = !_showUi),
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: total,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, i) => _ImagePage(image: widget.images[i]),
              ),
            ),
            // 上部: 閉じるボタン
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _showUi ? 1 : 0,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            // 下部: N/Total インジケータ
            if (total > 1)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _showUi ? 1 : 0,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  final MemoImage image;
  const _ImagePage({required this.image});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: ImageStorage.absolutePath(image.filePath),
      builder: (ctx, snap) {
        final path = snap.data;
        if (path == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        );
      },
    );
  }
}
