import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chile_puzzle/core/widgets/app_loader.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/audio_service.dart';
import '../../core/theme/app_theme.dart';

/// Full-screen overlay that lets the user pan/zoom the FULL source photo and
/// select any 1:1 square from it. On confirm, returns a [ui.Image] of the
/// cropped square, ready to feed into [ShareableCard].
///
/// The viewport is a rounded square clip. Inside, an [InteractiveViewer]
/// runs with `constrained: false` so the child (the image at intrinsic
/// dimensions) can be panned freely. An initial transformation scales-to-cover
/// and centers so the user starts with a full-square frame.
class ShareCropScreen extends StatefulWidget {
  const ShareCropScreen({
    super.key,
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  State<ShareCropScreen> createState() => _ShareCropScreenState();
}

class _ShareCropScreenState extends State<ShareCropScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _controller = TransformationController();

  ui.Image? _sourceImage;
  bool _capturing = false;
  double? _cropSide;
  bool _initialTransformApplied = false;

  /// Elastic settle: on gesture end, if the matrix is out of bounds, tween
  /// from the user's drop position back to the clamped target over ~260 ms
  /// with easeOutCubic. During the gesture we let InteractiveViewer run
  /// free (boundaryMargin: infinity) so drags stay 1:1 with the finger —
  /// no listener-clamp fighting the gesture stream.
  static const double _maxZoom = 10.0;
  late final AnimationController _settle;
  Matrix4? _settleFrom;
  Matrix4? _settleTo;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(_onSettleTick);
    _loadSourceImage();
  }

  @override
  void dispose() {
    _settle.removeListener(_onSettleTick);
    _settle.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final from = _settleFrom;
    final to = _settleTo;
    if (from == null || to == null) return;
    final t = Curves.easeOutCubic.transform(_settle.value);
    final sa = from.entry(0, 0);
    final sb = to.entry(0, 0);
    final txa = from.entry(0, 3);
    final txb = to.entry(0, 3);
    final tya = from.entry(1, 3);
    final tyb = to.entry(1, 3);
    final s = sa + (sb - sa) * t;
    final tx = txa + (txb - txa) * t;
    final ty = tya + (tyb - tya) * t;
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  void _onInteractionStart(_) {
    // User starts a new gesture mid-animation — stop the settle so their
    // drag picks up from the current interpolated position.
    if (_settle.isAnimating) {
      _settle.stop();
      _settleFrom = null;
      _settleTo = null;
    }
  }

  void _onInteractionEnd(_) {
    final image = _sourceImage;
    final side = _cropSide;
    if (image == null || side == null) return;
    final coverScale = math.max(side / image.width, side / image.height);
    final m = _controller.value;
    final rawScale = m.entry(0, 0);
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);
    final scale = rawScale.clamp(coverScale, coverScale * _maxZoom);
    final displayW = image.width * scale;
    final displayH = image.height * scale;
    final minTx = side - displayW;
    const maxTx = 0.0;
    final minTy = side - displayH;
    const maxTy = 0.0;
    final cx = tx.clamp(minTx, maxTx);
    final cy = ty.clamp(minTy, maxTy);
    if (scale == rawScale && cx == tx && cy == ty) return; // already valid
    _settleFrom = m.clone();
    _settleTo = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, cx)
      ..setEntry(1, 3, cy);
    _settle.forward(from: 0);
  }

  Future<void> _loadSourceImage() async {
    final provider = CachedNetworkImageProvider(widget.imageUrl);
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (err, _) {
        if (!completer.isCompleted) completer.completeError(err);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    try {
      final image = await completer.future;
      if (!mounted) return;
      _sourceImage = image;
      // Apply the cover transform BEFORE rebuild so the first render of the
      // InteractiveViewer already shows the image at cover-scale + centered.
      // Without this, there's a 1-frame window where the image draws at
      // identity transform (tiny in viewport with black around it) and a
      // fast tap on Continuar would capture that.
      if (_cropSide != null) {
        _applyInitialTransform();
      }
      setState(() {});
    } catch (_) {
      // Surface noop — crop screen will just stay on placeholder.
    }
  }

  /// Scale image to cover the square viewport, center it, apply to the
  /// transformation controller. Safe to call multiple times.
  void _applyInitialTransform() {
    final image = _sourceImage;
    final side = _cropSide;
    if (image == null || side == null || _initialTransformApplied) return;
    final scale = math.max(side / image.width, side / image.height);
    final displayW = image.width * scale;
    final displayH = image.height * scale;
    final dx = (side - displayW) / 2;
    final dy = (side - displayH) / 2;
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
    _initialTransformApplied = true;
  }

  Future<void> _confirm() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    AudioService.playPolaroid();
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // 3x so the crop has resolution for the 760px polaroid photo area.
      final image = await boundary.toImage(pixelRatio: 3.0);
      if (!mounted) return;
      Navigator.of(context).pop<ui.Image>(image);
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final size = MediaQuery.of(context).size;
    final side = (size.width - 32).clamp(200.0, size.height - 240);
    _cropSide = side;
    // Apply initial transform as soon as we have both image + viewport side.
    if (_sourceImage != null && !_initialTransformApplied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyInitialTransform();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header — title on the left, close on the right per app convention.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      langCode == 'es' ? 'Encuadra tu foto' : 'Frame your photo',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _capturing
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(PhosphorIconsBold.x, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    children: [
                      // Outer ClipRRect gives the rounded viewport. Sepia is
                      // applied as an ancestor of the RepaintBoundary so it
                      // stays visual-only (RB.toImage captures descendants,
                      // not ancestor effects). Vignette is INSIDE the RB so
                      // it bakes into the capture and travels with the share.
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ColorFiltered(
                            colorFilter: _sepiaMatrix(0.55),
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black,
                                      child: _sourceImage == null
                                          ? const Center(
                                              child: AppLoader(size: 56),
                                            )
                                          : Builder(
                                              builder: (_) {
                                                final coverScale = math.max(
                                                  side / _sourceImage!.width,
                                                  side / _sourceImage!.height,
                                                );
                                                return InteractiveViewer(
                                                  transformationController:
                                                      _controller,
                                                  constrained: false,
                                                  minScale: coverScale,
                                                  maxScale:
                                                      coverScale * _maxZoom,
                                                  // Hard-clamp pan at the
                                                  // image edges. No rubber-
                                                  // band past the photo:
                                                  // drags stop cleanly when
                                                  // the image edge hits the
                                                  // viewport edge, regardless
                                                  // of portrait / landscape.
                                                  boundaryMargin:
                                                      EdgeInsets.zero,
                                                  clipBehavior: Clip.hardEdge,
                                                  onInteractionStart:
                                                      _onInteractionStart,
                                                  onInteractionEnd:
                                                      _onInteractionEnd,
                                                  child: RawImage(
                                                    image: _sourceImage,
                                                    width: _sourceImage!
                                                        .width
                                                        .toDouble(),
                                                    height: _sourceImage!
                                                        .height
                                                        .toDouble(),
                                                    fit: BoxFit.fill,
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                  // Vignette baked into the capture (inside
                                  // the RepaintBoundary) so the shared PNG
                                  // carries the same darkened corners.
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            center: Alignment.center,
                                            radius: 0.95,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black
                                                  .withValues(alpha: 0.34),
                                            ],
                                            stops: const [0.58, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Centered crosshair guide, light and non-interactive.
                      // NOT captured — it sits OUTSIDE the RepaintBoundary above.
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: Center(child: _Crosshair()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Hint text
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Text(
                langCode == 'es'
                    ? 'Pellizca y arrastra para encuadrar'
                    : 'Pinch and drag to frame',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
            // Bottom confirm button (thumb-reach duplicate).
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  // Blocked until the cover transform is actually applied —
                  // prevents capturing the identity-frame (tiny image on
                  // black Container) before the InteractiveViewer has
                  // laid the photo out at cover-scale.
                  onPressed: (_capturing ||
                          _sourceImage == null ||
                          !_initialTransformApplied)
                      ? null
                      : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.ctaPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(PhosphorIconsBold.check, size: 18),
                  label: Text(
                    langCode == 'es' ? 'Continuar' : 'Continue',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
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

/// Builds a [ColorFilter] that blends a full sepia tone toward the identity
/// matrix by [strength] (0 = no sepia, 1 = full sepia).
///
/// Standard sepia matrix (strength 1):
///     R: 0.393 0.769 0.189
///     G: 0.349 0.686 0.168
///     B: 0.272 0.534 0.131
///
/// Pre-blended with identity here for the given [strength].
ColorFilter _sepiaMatrix(double strength) {
  final s = strength.clamp(0.0, 1.0);
  final inv = 1.0 - s;
  return ColorFilter.matrix([
    0.393 * s + inv, 0.769 * s,       0.189 * s,       0, 0,
    0.349 * s,       0.686 * s + inv, 0.168 * s,       0, 0,
    0.272 * s,       0.534 * s,       0.131 * s + inv, 0, 0,
    0,               0,               0,               1, 0,
  ]);
}

/// Subtle "+" crosshair painted over the crop area to help the user center.
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _CrosshairPainter()),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    // Horizontal
    canvas.drawLine(
      Offset(c.dx - size.width / 2, c.dy),
      Offset(c.dx + size.width / 2, c.dy),
      paint,
    );
    // Vertical
    canvas.drawLine(
      Offset(c.dx, c.dy - size.height / 2),
      Offset(c.dx, c.dy + size.height / 2),
      paint,
    );
    // Center dot
    canvas.drawCircle(
      c,
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) => false;
}
