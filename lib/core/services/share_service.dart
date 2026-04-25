import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/share/share_crop_screen.dart';
import '../../features/share/share_preview_overlay.dart';
import '../../features/share/shareable_card.dart';
import '../models/location_model.dart';
import 'game_progress_service.dart';

class ShareService {
  static const String _landingUrl = 'https://games.sabino.cl/zoominchile';

  /// One-shot share reward by difficulty (column count). Easy/beginner = 50,
  /// medium = 100, hard = 150, expert/master = 200. Awarded at most once
  /// per puzzle (gated by [PuzzleResult.hasShared]).
  static int rewardForDifficulty(int difficulty) {
    switch (difficulty) {
      case 3:
      case 4:
        return 50;
      case 5:
        return 100;
      case 6:
        return 150;
      case 8:
      case 10:
        return 200;
      default:
        return 100;
    }
  }

  /// Full share flow. Opens crop UI, renders the shareable PNG, then shows a
  /// preview with a Share button that invokes the native share sheet.
  static Future<void> shareLocation({
    required BuildContext context,
    required LocationModel location,
    required int difficulty,
    required String langCode,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = Overlay.of(context, rootOverlay: true);

    // 0. Prime the hug stamp into the image cache so the later off-screen
    //    render captures it on the first try. Without this, the asset's async
    //    decode can finish *after* RepaintBoundary.toImage and the stamp comes
    //    out missing. Repeat shares hit the cache and worked; the first one
    //    raced. precacheImage keeps a 'ephemeral' context-free reference in
    //    Flutter's global ImageCache.
    // ignore: use_build_context_synchronously
    await precacheImage(
      const AssetImage('assets/girl_cat_hug_sharer.png'),
      context,
    );

    // 1. Crop — user frames a 1:1 region of the source photo.
    final imageUrl = location.getImageForDifficulty(difficulty);
    final cropped = await navigator.push<ui.Image>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShareCropScreen(imageUrl: imageUrl),
      ),
    );
    if (cropped == null) return;

    // 2. Kick off PNG render in parallel with the preview appearing.
    //    The preview overlay awaits this future; it shows the flash until done.
    final pngPathFuture = _renderShareablePng(
      overlay: overlay,
      croppedPhoto: cropped,
    );

    final name = location.getLocalizedName(langCode);
    final tip = location.getLocalizedTipForDifficulty(langCode, difficulty);
    final caption = langCode == 'es'
        ? '$name — Zoom-In Chile 🧩 Descúbrelo en $_landingUrl'
        : '$name — Zoom-In Chile 🧩 Discover it at $_landingUrl';

    final reward = rewardForDifficulty(difficulty);
    final alreadyClaimed =
        GameProgressService.puzzleResult(location.id, difficulty)?.hasShared ??
            false;

    // 3. Preview + share.
    await navigator.push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => SharePreviewOverlay(
          pngPathFuture: pngPathFuture,
          croppedPhoto: cropped,
          tipText: tip,
          rewardPoints: reward,
          alreadyClaimed: alreadyClaimed,
          onShare: (path) async {
            final result = await Share.shareXFiles(
              [XFile(path, mimeType: 'image/png')],
              text: caption,
            );
            // success: confirmed share (iOS, some Android targets).
            // unavailable: Android often returns this even on a real share —
            // share_plus can't read the result reliably on most OEMs, so we
            // treat "unavailable" as success there. dismissed: user backed out.
            final ok = result.status == ShareResultStatus.success ||
                (Platform.isAndroid &&
                    result.status == ShareResultStatus.unavailable);
            if (!ok || alreadyClaimed) return false;
            await GameProgressService.markShared(location.id, difficulty);
            await GameProgressService.addReward(reward);
            return true;
          },
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );

    // Cleanup the temp file on overlay dismiss.
    try {
      final path = await pngPathFuture;
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort cleanup — ignore.
    }
  }

  /// Renders [ShareableCard] off-screen and returns the temp PNG path.
  static Future<String> _renderShareablePng({
    required OverlayState overlay,
    required ui.Image croppedPhoto,
  }) async {
    final boundaryKey = GlobalKey();
    late OverlayEntry entry;
    final completer = Completer<String>();

    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Render off-screen so nothing visible changes on the user's display.
        left: -20000,
        top: -20000,
        child: Material(
          color: Colors.transparent,
          child: ShareableCard(
            croppedPhoto: croppedPhoto,
            boundaryKey: boundaryKey,
          ),
        ),
      ),
    );
    overlay.insert(entry);

    // Let two frames elapse so the card lays out and paints.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    try {
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('ShareableCard did not mount a RenderRepaintBoundary');
      }
      // Card's logical size IS its output pixel size — capture 1:1.
      final image = await renderObject.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('toByteData returned null');
      }
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'zoominchile_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file.path);
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      entry.remove();
    }

    return completer.future;
  }
}
