import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Off-screen widget rendered to a PNG via RepaintBoundary.toImage.
///
/// Deliberately minimal: cream canvas + tilted polaroid of a cropped photo +
/// girl_cat_hug_sharer stamped at the bottom-right. No text is burned in —
/// the location name and link travel only in the native share sheet text.
///
/// The widget's logical size IS the output pixel size (render with
/// pixelRatio: 1.0).
class ShareableCard extends StatelessWidget {
  const ShareableCard({
    super.key,
    required this.croppedPhoto,
    required this.boundaryKey,
  });

  final ui.Image croppedPhoto;
  final GlobalKey boundaryKey;

  // Bottom-right stamp — shared constant so the preview renders at the exact
  // same position and size.
  static const double stampWidth = 520;

  static const double canvasWidth = 1080;
  static const double canvasHeight = 1350;
  static const Color creamBg = Color(0xFFFAF5EA);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            width: canvasWidth,
            height: canvasHeight,
            color: creamBg,
            child: Stack(
              children: [
                // Polaroid, center-aligned, slightly tilted.
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, -0.15),
                    child: Transform.rotate(
                      angle: -1.5 * 3.1415926535 / 180, // -1.5°
                      child: _Polaroid(photo: croppedPhoto),
                    ),
                  ),
                ),
                // Bottom-right hug stamp — anchors to the corner and grows
                // toward the center. Always present in the shared PNG.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/girl_cat_hug_sharer.png',
                    width: stampWidth,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.photo});

  final ui.Image photo;

  // Photo area is square; white frame adds sides/top/bottom padding.
  // Shared constants — the preview reuses them so visual scales match.
  static const double photoSide = 840;
  static const double frameSide = 52;
  static const double frameTop = 52;
  static const double frameBottom = 164;
  static const double cornerRadius = 20;

  @override
  Widget build(BuildContext context) {
    final totalWidth = photoSide + frameSide * 2;
    final totalHeight = photoSide + frameTop + frameBottom;
    return Container(
      width: totalWidth,
      height: totalHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cornerRadius),
        // Tight, dark contact shadow — the "at rest" state.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        frameSide, frameTop, frameSide, frameBottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: photoSide,
          height: photoSide,
          child: RawImage(
            image: photo,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// Exposed shape constants so the preview overlay can rebuild a matching
/// polaroid at a scaled size during the landing animation.
class ShareablePolaroidShape {
  static const double photoSide = _Polaroid.photoSide;
  static const double frameSide = _Polaroid.frameSide;
  static const double frameTop = _Polaroid.frameTop;
  static const double frameBottom = _Polaroid.frameBottom;
  static const double cornerRadius = _Polaroid.cornerRadius;

  static const double totalWidth = photoSide + frameSide * 2;
  static const double totalHeight = photoSide + frameTop + frameBottom;
}
