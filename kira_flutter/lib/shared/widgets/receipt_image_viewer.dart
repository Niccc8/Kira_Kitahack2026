/// Receipt Image Viewer
///
/// Premium glassmorphism fullscreen overlay for viewing receipt images.
/// Features: backdrop blur, smooth scale animation, pinch-to-zoom,
/// tap-outside-to-close, and edge-to-edge display.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'storage_image.dart';

/// Opens a premium fullscreen receipt image viewer overlay.
///
/// Usage:
/// ```dart
/// ReceiptImageViewer.show(context, imageUrl: receipt.imageUrl!);
/// ```
class ReceiptImageViewer {
  /// Show the receipt image in a premium fullscreen overlay.
  static void show(
    BuildContext context, {
    required String imageUrl,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ReceiptImageOverlay(
            imageUrl: imageUrl,
            animation: animation,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child; // Animation handled internally
        },
      ),
    );
  }
}

class _ReceiptImageOverlay extends StatefulWidget {
  final String imageUrl;
  final Animation<double> animation;

  const _ReceiptImageOverlay({
    required this.imageUrl,
    required this.animation,
  });

  @override
  State<_ReceiptImageOverlay> createState() => _ReceiptImageOverlayState();
}

class _ReceiptImageOverlayState extends State<_ReceiptImageOverlay>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  late AnimationController _zoomResetController;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _zoomResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    _zoomResetController.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (_isClosing) return;
    _isClosing = true;
    Navigator.of(context).pop();
  }

  /// Reset zoom with a smooth animation
  void _resetZoom() {
    final currentMatrix = _transformController.value;
    if (currentMatrix == Matrix4.identity()) return;

    final animation = Matrix4Tween(
      begin: currentMatrix,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _zoomResetController,
      curve: Curves.easeOutCubic,
    ));

    void listener() {
      _transformController.value = animation.value;
      if (animation.isCompleted) {
        animation.removeListener(listener);
      }
    }
    animation.addListener(listener);
    _zoomResetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final curvedValue = Curves.easeOutQuart.transform(widget.animation.value);
        final blurValue = curvedValue * 28.0;
        final scaleValue = 0.88 + (0.12 * curvedValue);
        final opacityValue = curvedValue;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── Blurred backdrop — tap to dismiss ──
            GestureDetector(
              onTap: _handleClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurValue,
                  sigmaY: blurValue,
                ),
                child: Container(
                  color: Colors.black.withOpacity(0.6 * opacityValue),
                ),
              ),
            ),

            // ── Image — edge-to-edge, centered vertically ──
            SafeArea(
              child: Center(
                child: Transform.scale(
                  scale: scaleValue,
                  child: Opacity(
                    opacity: opacityValue,
                    child: GestureDetector(
                      onDoubleTap: _resetZoom,
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 50,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 5.0,
                            clipBehavior: Clip.hardEdge,
                            child: StorageImage(
                              url: widget.imageUrl,
                              fit: BoxFit.contain,
                              fallback: _buildErrorState(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom hint ──
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: opacityValue * 0.5,
                child: Text(
                  'Pinch to zoom • Double-tap to reset • Tap outside to close',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: 280,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load receipt image',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
