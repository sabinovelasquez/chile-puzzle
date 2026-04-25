import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'shareable_card.dart';

enum _Phase { reveal, idle }

/// Preview stage for the share flow.
///
/// Composes the same layout as the shared PNG (cream canvas + polaroid +
/// bottom-right hug stamp) as independently animated layers, so the polaroid
/// can "land" before the stamp fades in. Final resting state matches the PNG
/// baked by [ShareableCard] 1:1.
class SharePreviewOverlay extends StatefulWidget {
  const SharePreviewOverlay({
    super.key,
    required this.pngPathFuture,
    required this.croppedPhoto,
    required this.tipText,
    required this.onShare,
    required this.rewardPoints,
    required this.alreadyClaimed,
  });

  final Future<String> pngPathFuture;
  final ui.Image croppedPhoto;
  final String tipText;
  /// Returns true if this share invocation actually awarded the reward
  /// (i.e. result was successful AND the puzzle hadn't been shared before).
  final Future<bool> Function(String pngPath) onShare;
  final int rewardPoints;
  final bool alreadyClaimed;

  @override
  State<SharePreviewOverlay> createState() => _SharePreviewOverlayState();
}

class _SharePreviewOverlayState extends State<SharePreviewOverlay>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.reveal;
  String? _pngPath;
  bool _sharing = false;
  // Local "claimed in this session" flag — flips true after a successful
  // share returns true. Combined with widget.alreadyClaimed it gates the
  // reward chip copy ("earn vs received").
  bool _justClaimed = false;

  late final AnimationController _slip;
  late final Animation<double> _slipT;

  @override
  void initState() {
    super.initState();
    _slip = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _slipT = CurvedAnimation(parent: _slip, curve: Curves.easeOutCubic);
    // Start animating immediately — the PNG render proceeds in parallel.
    _slip.forward().whenComplete(() {
      if (mounted) setState(() => _phase = _Phase.idle);
    });
    _attachPng();
  }

  Future<void> _attachPng() async {
    try {
      final path = await widget.pngPathFuture;
      if (!mounted) return;
      setState(() => _pngPath = path);
    } catch (_) {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _slip.dispose();
    super.dispose();
  }

  Future<void> _doShare() async {
    final path = _pngPath;
    if (_sharing || path == null) return;
    setState(() => _sharing = true);
    bool awarded = false;
    try {
      awarded = await widget.onShare(path);
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
          if (awarded) _justClaimed = true;
        });
      }
    }
    if (awarded && mounted) {
      final langCode = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'es'
              ? '+${widget.rewardPoints} pts por compartir'
              : '+${widget.rewardPoints} pts for sharing'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    // Share button is enabled once both: animation finished AND PNG ready.
    final canShare =
        _phase == _Phase.idle && _pngPath != null && !_sharing;

    return Scaffold(
      backgroundColor: ShareableCard.creamBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Close — top-right per app convention.
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed:
                    _sharing ? null : () => Navigator.of(context).maybePop(),
                icon: Icon(PhosphorIconsBold.x, color: Colors.grey.shade700),
              ),
            ),
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 56),
                  Expanded(
                    flex: 6,
                    child: Center(child: _buildPreviewStage()),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                      child: AnimatedOpacity(
                        opacity: _phase == _Phase.idle ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 320),
                        child: _AutoSizedTip(text: widget.tipText),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                    child: AnimatedOpacity(
                      opacity: _phase == _Phase.idle ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RewardChip(
                            points: widget.rewardPoints,
                            claimed: widget.alreadyClaimed || _justClaimed,
                            langCode: langCode,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: canShare ? _doShare : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.ctaPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(PhosphorIconsBold.shareNetwork,
                                  size: 18),
                          label: Text(
                            langCode == 'es' ? 'Compartir' : 'Share',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth * 0.92;
        final availH = constraints.maxHeight * 0.98;
        // PNG aspect: 1080 × 1350 = 4:5.
        double stageW = availW;
        double stageH = stageW *
            (ShareableCard.canvasHeight / ShareableCard.canvasWidth);
        if (stageH > availH) {
          stageH = availH;
          stageW = stageH *
              (ShareableCard.canvasWidth / ShareableCard.canvasHeight);
        }
        final s = stageW / ShareableCard.canvasWidth;

        return SizedBox(
          width: stageW,
          height: stageH,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Cream canvas — matches the shared PNG bg.
              Positioned.fill(child: Container(color: ShareableCard.creamBg)),
              // Animated polaroid.
              _AnimatedPolaroid(
                photo: widget.croppedPhoto,
                stageW: stageW,
                stageH: stageH,
                scale: s,
                slipT: _slipT,
              ),
              // Bottom-right hug stamp — always present, fades in after the
              // polaroid lands.
              Positioned(
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _phase == _Phase.idle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 420),
                    child: Image.asset(
                      'assets/girl_cat_hug_sharer.png',
                      width: ShareableCard.stampWidth * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPolaroid extends StatelessWidget {
  const _AnimatedPolaroid({
    required this.photo,
    required this.stageW,
    required this.stageH,
    required this.scale,
    required this.slipT,
  });

  final ui.Image photo;
  final double stageW;
  final double stageH;
  final double scale;
  final Animation<double> slipT;

  @override
  Widget build(BuildContext context) {
    final polW = ShareablePolaroidShape.totalWidth * scale;
    final polH = ShareablePolaroidShape.totalHeight * scale;
    final landedLeft = (stageW - polW) / 2;
    final landedTop = (stageH - polH) * 0.26;

    return AnimatedBuilder(
      animation: slipT,
      builder: (context, _) {
        final t = slipT.value;
        // Slip in from above-right toward center, like a polaroid sliding
        // out of an unseen camera at the top of the frame. Same magnitude
        // as the prior bottom-right entry, vertically mirrored.
        final dx = (1 - t) * stageW * 0.55;
        final dy = -(1 - t) * stageH * 0.55;
        final scaleFactor = 0.94 + 0.06 * t;
        // Shadow evolves: wide+soft during flight → tight+dark on contact.
        final blur = 48.0 - 32.0 * t;
        final offsetY = 40.0 - 34.0 * t;
        final alpha = 0.10 + 0.18 * t;

        return Positioned(
          left: landedLeft + dx,
          top: landedTop + dy,
          width: polW,
          height: polH,
          child: Transform.scale(
            scale: scaleFactor,
            child: Transform.rotate(
              angle: -1.5 * 3.1415926535 / 180,
              child: _PreviewPolaroid(
                photo: photo,
                shadowBlur: blur,
                shadowOffsetY: offsetY,
                shadowAlpha: alpha,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewPolaroid extends StatelessWidget {
  const _PreviewPolaroid({
    required this.photo,
    required this.shadowBlur,
    required this.shadowOffsetY,
    required this.shadowAlpha,
  });

  final ui.Image photo;
  final double shadowBlur;
  final double shadowOffsetY;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final shrink = constraints.maxWidth / ShareablePolaroidShape.totalWidth;
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ShareablePolaroidShape.cornerRadius * shrink,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: shadowBlur * shrink,
              offset: Offset(0, shadowOffsetY * shrink),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          ShareablePolaroidShape.frameSide * shrink,
          ShareablePolaroidShape.frameTop * shrink,
          ShareablePolaroidShape.frameSide * shrink,
          ShareablePolaroidShape.frameBottom * shrink,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22 * shrink),
          child: SizedBox.expand(
            child: RawImage(image: photo, fit: BoxFit.cover),
          ),
        ),
      );
    });
  }
}

/// Small pill above the Share button that advertises the share reward
/// while it's still claimable, then flips to a "received" state once
/// awarded (either previously or in this session).
class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.points,
    required this.claimed,
    required this.langCode,
  });

  final int points;
  final bool claimed;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    final claimedText = langCode == 'es'
        ? 'Recompensa recibida'
        : 'Reward received';
    final offerText = langCode == 'es'
        ? 'Comparte y gana +$points pts'
        : 'Share & earn +$points pts';
    final color = AppTheme.accentGreen;
    final icon = claimed
        ? PhosphorIconsBold.checkCircle
        : PhosphorIconsBold.gift;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            claimed ? claimedText : offerText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoSizedTip extends StatelessWidget {
  const _AutoSizedTip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 56,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            height: 1.4,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
