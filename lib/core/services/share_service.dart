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
import '../models/game_config.dart';
import '../models/location_model.dart';
import 'game_progress_service.dart';
import 'mock_backend.dart';

class ShareService {

  /// Flat one-shot share reward, awarded once per location regardless of
  /// which difficulty the player came from. Visualised in the preview chip
  /// alongside the row of completed-difficulty icons.
  static const int shareReward = 50;

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

    // 1. Crop — user frames a 1:1 region of the source photo. Prefer the
    //    untouched original upload (full resolution) when the backend has
    //    one stored; falls back to the per-difficulty pre-rendered crop or
    //    the standard image. The crop screen pans/zooms freely so a larger
    //    source means more detail under the lens.
    final imageUrl = location.getBestSourceImage(difficulty);
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
    // Always use the base (easiest) tip in the share preview — the harder
    // difficulty overrides give away too much, and the polaroid reads better
    // with a general line about the place rather than a level-specific clue.
    final tip = location.getLocalizedTip(langCode);
    final share = MockBackend.lastConfig?.share ?? ShareConfig.fallback;
    final caption = share
        .textForLocale(langCode)
        .replaceAll('{name}', name)
        .replaceAll('{link}', share.link);

    // Reward is one-shot per LOCATION, gated on at least one completed
    // difficulty. The reward number is always 50.
    final eligible = location.difficultyLevels.any(
        (d) => GameProgressService.puzzleResult(location.id, d) != null);
    final alreadyClaimed =
        GameProgressService.hasSharedLocation(location.id);

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
          rewardPoints: eligible ? shareReward : 0,
          alreadyClaimed: !eligible || alreadyClaimed,
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
            if (!ok || !eligible || alreadyClaimed) return false;
            // markLocationShared returns true only when this call is the
            // one that flips the flag — protects against double-credit.
            final flipped = await GameProgressService.markLocationShared(
              location.id,
            );
            if (!flipped) return false;
            await GameProgressService.addReward(shareReward);
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
