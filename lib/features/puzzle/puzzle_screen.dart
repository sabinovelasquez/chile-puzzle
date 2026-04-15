import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:chile_puzzle/core/services/audio_service.dart';
import 'package:chile_puzzle/core/services/settings_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chile_puzzle/features/puzzle/puzzle_engine.dart';
import 'package:chile_puzzle/features/puzzle/completion_drawer.dart';
import 'package:chile_puzzle/features/ads/ad_service.dart';

// Difficulty accent colors — mirrors the palette used on map_screen.dart so
// the "level completed" pill reads the same across screens.
const _diffColors = {
  3: AppTheme.accentGreen,
  4: AppTheme.accentOrange,
  5: AppTheme.accentBlue,
  6: AppTheme.accentPurple,
};

const _diffLabelPillEs = {
  3: 'Fácil completado',
  4: 'Normal completado',
  5: 'Difícil completado',
  6: 'Experto completado',
};
const _diffLabelPillEn = {
  3: 'Easy completed',
  4: 'Normal completed',
  5: 'Hard completed',
  6: 'Expert completed',
};

/// Small rounded "{Level} completed" pill used above the tip text on the
/// post-completion photo overlay and inside the map-screen full-photo
/// carousel. Color-coded by difficulty so it matches the rest of the app.
Widget _buildLevelPill({required int difficulty, required String langCode}) {
  final color = _diffColors[difficulty] ?? AppTheme.accentBlue;
  final label =
      (langCode == 'es' ? _diffLabelPillEs : _diffLabelPillEn)[difficulty] ??
          '';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: color.withValues(alpha: 0.40),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsFill.checkCircle, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

class PuzzleScreen extends StatefulWidget {
  final LocationModel location;
  final int difficulty;
  final GameConfig gameConfig;
  final List<LocationModel> allLocations;
  final bool lockInPlace;
  final bool multiSelect;
  final bool referenceEnabled;

  const PuzzleScreen({
    super.key,
    required this.location,
    required this.difficulty,
    required this.gameConfig,
    required this.allLocations,
    this.lockInPlace = false,
    this.multiSelect = false,
    this.referenceEnabled = false,
  });

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with TickerProviderStateMixin {
  CompletionResult? _result;
  bool _completed = false;
  bool _showDrawer = true;
  bool _firstDrawerShow = true;
  bool _showReference = false;
  // Reference image starts at 3 peeks per puzzle session — each open
  // decrements, closing is free. When spent, tapping prompts a rewarded-ad
  // dialog that grants +3 more on dismiss. Count shown as a badge.
  static const int _referenceStartUses = 3;
  static const int _referenceAdRefill = 3;
  int _referenceUsesLeft = _referenceStartUses;
  bool _tipsVisible = true;
  bool _silFadingOut = false;

  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _moveCount = ValueNotifier(0);
  final ValueNotifier<bool> _imageLoaded = ValueNotifier(false);

  // Help state — unlimited uses, gated only by the 2 min cooldown bar.
  static const int _helpCooldownSecs = 120;
  // Incrementing counter — any value change signals the engine to pick the
  // farthest mispositioned piece and animate a ghost to its correct cell.
  final ValueNotifier<int?> _helpFlashPieceId = ValueNotifier(null);
  Timer? _helpFlashTimer;
  // Single controller drives the full bar lifecycle: starts at 1.0 (ready),
  // animateTo(0, 500ms) on use, then animateTo(1, 120s) for refill. The
  // lifebuoy becomes tappable again once value hits 1.0.
  late final AnimationController _helpBarController;
  // Rising red first-aid icon — cosmetic "effect released" puff above the
  // lifebuoy that fires once per help use.
  late final AnimationController _helpRisingController;
  // Fires once each time the cooldown completes — drives the shimmer/flash
  // "ready!" flourish on the help button, mode picked from SettingsService.
  late final AnimationController _helpReadyEffectController;

  final List<_PendingNotification> _notificationQueue = [];
  bool _notificationShowing = false;

  static const Map<int, String> _diffLabelsEs = {
    3: 'Fácil', 4: 'Normal', 5: 'Difícil', 6: 'Experto',
  };
  static const Map<int, String> _diffLabelsEn = {
    3: 'Easy', 4: 'Normal', 5: 'Hard', 6: 'Expert',
  };

  late final StreamSubscription _timerSub;

  @override
  void initState() {
    super.initState();
    _timerSub = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted && _stopwatch.isRunning) setState(() {});
    });
    _helpBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    )..addStatusListener((status) {
        // Refresh the lifebuoy button when refill hits 1.0 (ready again).
        if (status == AnimationStatus.completed && mounted) {
          setState(() {});
          // Only fire a ready flourish if the refill finished at 1.0 (not
          // when the 500ms drain completed at 0.0 on tap).
          if (_helpBarController.value >= 0.999 &&
              SettingsService.shimmerMode != ShimmerMode.off) {
            _helpReadyEffectController.forward(from: 0.0);
          }
        }
      });
    _helpRisingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _helpReadyEffectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _timerSub.cancel();
    _helpFlashTimer?.cancel();
    _helpBarController.dispose();
    _helpRisingController.dispose();
    _helpReadyEffectController.dispose();
    _helpFlashPieceId.dispose();
    super.dispose();
  }

  bool get _canUseHelp {
    if (_completed) return false;
    return _helpBarController.value >= 0.999;
  }

  /// Drains the bar first (critical: bar must visibly empty BEFORE the tip
  /// appears, so the player understands the bar is the tip cooldown), then
  /// triggers the engine to auto-pick the farthest mispositioned piece and
  /// animate a ghost to its correct cell. Finally kicks off the 120 s refill.
  Future<void> _onHelpTapped() async {
    if (!_canUseHelp) return;
    // Reference overlay would cover the hint animation — close it first.
    if (_showReference) setState(() => _showReference = false);
    _helpBarController.stop();
    await _helpBarController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    if (!mounted) return;
    // Bump the notifier (incrementing counter) — engine ignores the value,
    // just treats any change as a trigger to pick the farthest piece.
    _helpFlashPieceId.value = (_helpFlashPieceId.value ?? 0) + 1;
    _helpFlashTimer?.cancel();
    _helpFlashTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) _helpFlashPieceId.value = null;
    });
    // Visual flourish: a red first-aid icon rises from the help button as
    // the ghost begins its run, fading out in ~900 ms.
    _helpRisingController.forward(from: 0.0);
    // Unlimited uses — cooldown is the only gate, so always schedule refill.
    _helpBarController.animateTo(
      1.0,
      duration: const Duration(seconds: _helpCooldownSecs),
      curve: Curves.linear,
    );
  }

  /// Prompts the player to watch a rewarded-style interstitial in exchange
  /// for 3 more reference-image peeks in this session. Only shown when the
  /// count has hit zero.
  Future<void> _showReferenceRefillDialog() async {
    final langCode = Localizations.localeOf(context).languageCode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      PhosphorIconsBold.image,
                      size: 30,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsBold.megaphoneSimple,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '+$_referenceAdRefill',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                langCode == 'es'
                    ? 'Ver anuncio para $_referenceAdRefill más'
                    : 'Watch ad for $_referenceAdRefill more',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                langCode == 'es'
                    ? 'Desbloquea $_referenceAdRefill vistas más de la imagen de referencia en este puzzle.'
                    : 'Unlock $_referenceAdRefill more reference-image peeks in this puzzle.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        langCode == 'es' ? 'Cancelar' : 'Cancel',
                        style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(PhosphorIconsBold.megaphoneSimple, size: 16),
                      label: Text(langCode == 'es' ? 'Ver' : 'Watch'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true || !mounted) return;
    AdService.showInterstitial(
      onAdDismissed: () {
        if (!mounted) return;
        setState(() => _referenceUsesLeft += _referenceAdRefill);
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (_completed) return false; // Force exit through "Seguir" button (triggers ad)
    final langCode = Localizations.localeOf(context).languageCode;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          langCode == 'es' ? '¿Salir del puzzle?' : 'Exit puzzle?',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        content: Text(
          langCode == 'es'
              ? 'Se perderá el avance actual.'
              : 'Current progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(langCode == 'es' ? 'No' : 'No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              langCode == 'es' ? 'Sí, salir' : 'Yes, exit',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  Future<void> _handleCompletion(int timeSecs, int moves, int rows, int cols) async {
    final result = await GameProgressService.recordCompletion(
      locationId: widget.location.id,
      difficulty: widget.difficulty,
      timeSecs: timeSecs,
      moves: moves,
      totalPieces: rows * cols,
      scoring: widget.gameConfig.scoring,
      allTrophies: widget.gameConfig.trophies,
      allLocations: widget.allLocations,
      lockInPlace: widget.lockInPlace,
      multiSelect: widget.multiSelect,
      referenceEnabled: widget.referenceEnabled,
    );
    if (mounted) {
      Confetti.launch(context,
        options: const ConfettiOptions(particleCount: 100, spread: 70, y: 0.6),
      );
      AudioService.playVictory();
    }

    setState(() {
      _result = result;
      _completed = true;
      _showDrawer = true;
      _showReference = false;
    });

    if (!mounted) return;
    final langCode = Localizations.localeOf(context).languageCode;

    if (result.isNewBest) {
      final delta = result.totalPoints - result.previousBest;
      _enqueueNotification(
        icon: PhosphorIconsFill.crown,
        text: langCode == 'es'
            ? '¡Nuevo récord! +$delta pts'
            : 'New best! +$delta pts',
      );
    }

    for (final trophy in result.newTrophies) {
      _enqueueNotification(
        icon: PhosphorIconsFill.trophy,
        text: trophy.getLocalizedName(langCode),
      );
    }
  }

  void _enqueueNotification({required PhosphorIconData icon, required String text}) {
    _notificationQueue.add(_PendingNotification(icon: icon, text: text));
    if (!_notificationShowing) _drainNotifications();
  }

  Future<void> _drainNotifications() async {
    _notificationShowing = true;
    final overlay = Overlay.of(context);
    while (_notificationQueue.isNotEmpty && mounted) {
      final next = _notificationQueue.removeAt(0);
      final completer = Completer<void>();
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _TopNotification(
          icon: next.icon,
          text: next.text,
          onDismiss: () {
            entry.remove();
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );
      overlay.insert(entry);
      await completer.future;
      // Small gap so the next one doesn't overlap the dismiss animation.
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _notificationShowing = false;
  }

  String _bestLabel(String langCode) {
    final best = GameProgressService.getBestPoints(widget.location.id, widget.difficulty);
    final labels = langCode == 'es' ? _diffLabelsEs : _diffLabelsEn;
    final diffLabel = labels[widget.difficulty] ?? '${widget.difficulty} col';
    final prefix = langCode == 'es' ? 'Mejor' : 'Best';
    final pts = best ?? 0;
    return '$prefix: $pts pts · $diffLabel';
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final secs = _stopwatch.elapsed.inSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;
    final showSil = _completed && !_showDrawer && _tipsVisible &&
        widget.location.showsSilhouetteAt(widget.difficulty);
    final silW = screenW * 0.48;
    final silH = silW * 623 / 749; // girl_cat_with_bottom.svg aspect
    // Toggle icon picks silhouette as a badge-of-honour when the player has
    // beaten Expert or cleared every difficulty the location exposes; falls
    // back to a plain bulb until then.
    final _progressMap = GameProgressService.progress.completedPuzzles;
    final _locDiffs = widget.location.difficultyLevels.isNotEmpty
        ? widget.location.difficultyLevels
        : const [3];
    final _expertDone = _progressMap.containsKey('${widget.location.id}_6');
    final _allDone = _locDiffs.every(
      (d) => _progressMap.containsKey('${widget.location.id}_$d'),
    );
    final tipToggleIsSilhouette = _expertDone || _allDone;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.seedColor,
        body: Stack(
          children: [
          Column(
          children: [
            // Puzzle area
            Expanded(
              child: Stack(
                children: [
                  PuzzleEngine(
                    location: widget.location,
                    difficulty: widget.difficulty,
                    onCompleted: _handleCompletion,
                    stopwatch: _stopwatch,
                    moveCount: _moveCount,
                    imageLoaded: _imageLoaded,
                    lockInPlace: widget.lockInPlace,
                    multiSelect: widget.multiSelect,
                    shimmerMode: SettingsService.shimmerMode,
                    helpFlashPieceId: _helpFlashPieceId,
                  ),
                  // Loading overlay — visible until image is loaded
                  ValueListenableBuilder<bool>(
                    valueListenable: _imageLoaded,
                    builder: (_, loaded, __) {
                      if (loaded) return const SizedBox.shrink();
                      return const Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: 95,
                            height: 95,
                            child: _LoaderGif(),
                          ),
                        ),
                      );
                    },
                  ),
                  // Reference image overlay + button (only after image loads)
                  ValueListenableBuilder<bool>(
                    valueListenable: _imageLoaded,
                    builder: (_, loaded, __) {
                      if (!loaded || _completed || !widget.referenceEnabled) {
                        return const SizedBox.shrink();
                      }
                      return Stack(
                        children: [
                          if (_showReference)
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => setState(() => _showReference = false),
                                child: Container(
                                  color: Colors.black,
                                  child: _ReferenceCropView(
                                    location: widget.location,
                                    difficulty: widget.difficulty,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                if (_showReference) {
                                  setState(() => _showReference = false);
                                } else if (_referenceUsesLeft > 0) {
                                  setState(() {
                                    _showReference = true;
                                    _referenceUsesLeft--;
                                  });
                                } else {
                                  _showReferenceRefillDialog();
                                }
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _showReference ? PhosphorIconsBold.x : PhosphorIconsBold.image,
                                      size: 20, color: Colors.white,
                                    ),
                                  ),
                                  // Badge — remaining count when > 0,
                                  // megaphone "tap-for-ad" when depleted.
                                  if (!_showReference)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        width: 20, height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _referenceUsesLeft > 0
                                              ? AppTheme.accentOrange
                                              : AppTheme.accentBlue,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: _referenceUsesLeft > 0
                                            ? Text(
                                                '$_referenceUsesLeft',
                                                style: GoogleFonts.spaceGrotesk(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  height: 1.0,
                                                ),
                                              )
                                            : const Icon(
                                                PhosphorIconsBold.megaphoneSimple,
                                                size: 11,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Fullscreen photo overlay — replaces the grid view after
                  // completion so the image fills the entire screen.
                  if (_completed && !_showDrawer)
                    Positioned.fill(
                      child: Container(
                        color: AppTheme.seedColor,
                        child: CachedNetworkImage(
                          imageUrl: widget.location
                              .getImageForDifficulty(widget.difficulty),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  // Tap anywhere to bring back the drawer when viewing the photo
                  if (_completed && !_showDrawer)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _showDrawer = true),
                      ),
                    ),
                  // Photo overlay: tip toggle + tip card + silhouette
                  // Shown on top of the solved puzzle when the drawer is dismissed.
                  // The tip card / toggle have their own opaque GestureDetectors so
                  // taps on them don't bubble to the tap-to-bring-drawer layer below;
                  // the silhouette is IgnorePointer, so taps on it fall through.
                  //
                  // Silhouette + tip card are bundled: tip OFF hides both; tip ON
                  // shows a light translucent card at the bottom with the silhouette
                  // drawn over the card's bottom-right corner (touching the footer).
                  if (_completed && !_showDrawer) ...[
                    // Tip toggle — top-right (girl+cat icon)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final wasVisible = _tipsVisible;
                          setState(() => _tipsVisible = !_tipsVisible);
                          if (wasVisible && showSil) {
                            _silFadingOut = true;
                            Future.delayed(const Duration(milliseconds: 280), () {
                              if (mounted) setState(() => _silFadingOut = false);
                            });
                          }
                        },
                        child: Opacity(
                          opacity: _tipsVisible ? 1.0 : 0.5,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: tipToggleIsSilhouette
                                ? Image.asset(
                                    'assets/girl_cat_toggle.png',
                                    fit: BoxFit.contain,
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      PhosphorIconsBold.lightbulb,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    // Tip card + silhouette — same layout as _FullPhotoView
                    // in map_screen.dart: Column anchored at bottom with
                    // tip above silhouette.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottomPadding,
                      top: 56,
                      child: Column(
                        mainAxisAlignment: (showSil || _silFadingOut)
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: _tipsVisible
                                  ? GestureDetector(
                                      key: const ValueKey('tip-card-on'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {},
                                      child: MediaQuery.withClampedTextScaling(
                                        maxScaleFactor: 1.3,
                                        child: Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            12, 0, 12,
                                            showSil ? 8 : 0,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.fromLTRB(
                                              14, 10, 10, 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.92),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    _buildLevelPill(
                                                      difficulty:
                                                          widget.difficulty,
                                                      langCode: langCode,
                                                    ),
                                                    const Spacer(),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setState(() => _tipsVisible = false);
                                                        if (showSil) {
                                                          _silFadingOut = true;
                                                          Future.delayed(const Duration(milliseconds: 280), () {
                                                            if (mounted) setState(() => _silFadingOut = false);
                                                          });
                                                        }
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4),
                                                        child: Icon(
                                                          PhosphorIconsBold.x,
                                                          size: 16,
                                                          color: Colors
                                                              .grey.shade500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Flexible(
                                                  child: SingleChildScrollView(
                                                    child: Text(
                                                      widget.location
                                                          .getLocalizedTipForDifficulty(
                                                        langCode,
                                                        widget.difficulty,
                                                      ),
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey.shade900,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('tip-card-off')),
                            ),
                          ),
                          // Silhouette — inside the Column, below the tip
                          IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: showSil
                                  ? SizedBox(
                                      key: const ValueKey('silhouette-on'),
                                      width: silW,
                                      height: silH,
                                      child: SvgPicture.asset(
                                        'assets/girl_cat_with_bottom.svg',
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('silhouette-off'),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Completion drawer
                  if (_completed && _showDrawer)
                    CompletionDrawer(
                      location: widget.location,
                      result: _result,
                      animate: _firstDrawerShow,
                      timeSecs: _stopwatch.elapsed.inSeconds,
                      moves: _moveCount.value,
                      onHide: () => setState(() {
                        _showDrawer = false;
                        _firstDrawerShow = false;
                      }),
                    ),
                ],
              ),
            ),
            // Help cooldown separator + bottom footer. Kept invisible (but
            // space reserved) while the image loads so the board sizes the
            // same before and after — otherwise the footer lands on top of
            // the bottom pieces when it reappears.
            ValueListenableBuilder<bool>(
              valueListenable: _imageLoaded,
              builder: (_, loaded, __) {
                return Visibility(
                  visible: loaded,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    if (!_completed)
                      AnimatedBuilder(
                        animation: _helpBarController,
                        builder: (_, __) {
                          final v = _helpBarController.value;
                          final color = Color.lerp(
                            Colors.white54,
                            AppTheme.accentGreen,
                            v,
                          )!;
                          return SizedBox(
                            height: 3,
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 3,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          );
                        },
                      ),
                    if (!_completed || _showDrawer)
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 12, 12, 12 + bottomPadding),
                color: AppTheme.seedColor,
                child: _completed
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.location.getLocalizedName(langCode),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ValueListenableBuilder<int>(
                                valueListenable: _moveCount,
                                builder: (_, moves, __) => Text(
                                  langCode == 'es'
                                      ? '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  ·  $moves movimientos'
                                      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  ·  $moves moves',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedOpacity(
                          opacity: _showDrawer ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _bestLabel(langCode),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () async {
                                if (await _onWillPop()) {
                                  if (mounted) Navigator.of(context).pop();
                                }
                              },
                              icon: const Icon(PhosphorIconsBold.arrowLeft, size: 22, color: Colors.white70),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _moveCount,
                              builder: (_, moves, __) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_stopwatch.isRunning)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(PhosphorIconsBold.pause, size: 12, color: Colors.white70),
                                      ),
                                    Text(
                                      '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  ·  $moves mov',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12, fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildHelpButton(langCode),
                          ),
                        ),
                      ],
                    ),
            ),
            ),
                  ],
                  ),
                );
              },
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpButton(String langCode) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _helpBarController,
        _helpReadyEffectController,
      ]),
      builder: (_, __) {
        final v = _helpBarController.value;
        final ready = v >= 0.999;
        // Saturation ramp: fully grayscale until 50% of the cooldown, then
        // lerps 0 → 1 as the bar fills the remaining half. Gives the button
        // a visible "charging" feel instead of a sudden state flip.
        final saturation =
            v < 0.5 ? 0.0 : ((v - 0.5) * 2).clamp(0.0, 1.0);
        // Opacity: 10% right after a tap, climbs to 100% as the bar refills.
        final buttonOpacity = (0.1 + 0.9 * v).clamp(0.1, 1.0);

        // Ready flourish — only animates after the bar completes refill.
        final et = _helpReadyEffectController.value;
        final effectMode = SettingsService.shimmerMode;
        final effectActive = ready &&
            et > 0 &&
            et < 1.0 &&
            effectMode != ShimmerMode.off;

        // Must match the reference-photo toggle button (40×40) so the footer
        // row height stays constant — the reference photo layout depends on
        // this footer height.
        const size = 40.0;

        // White effect: button stays white, visible via a pulsing white
        // box-shadow (flash) or a gentle white gradient sweep + halo
        // (shimmer). No colored tint — purely a "glow" aesthetic.
        BoxDecoration deco;
        if (effectActive && effectMode == ShimmerMode.flash) {
          final pulse =
              (et < 0.5 ? et * 2 : (1 - et) * 2).clamp(0.0, 1.0);
          deco = BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.85 * pulse),
                blurRadius: 20 * pulse,
                spreadRadius: 5 * pulse,
              ),
            ],
          );
        } else if (effectActive && effectMode == ShimmerMode.shimmer) {
          deco = BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 3.0 * et, -1.0 + 3.0 * et),
              end: Alignment(-0.5 + 3.0 * et, -0.5 + 3.0 * et),
              colors: [Colors.grey.shade100, Colors.white, Colors.grey.shade100],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          );
        } else {
          deco = const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          );
        }

        return GestureDetector(
          onTap: ready ? _onHelpTapped : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: buttonOpacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: deco,
                  alignment: Alignment.center,
                  child: ColorFiltered(
                    colorFilter: _saturationFilter(saturation),
                    child: Icon(
                      PhosphorIconsFill.pill,
                      size: 20,
                      color: Colors.red.shade500,
                    ),
                  ),
                ),
              ),
              // Red first-aid icon rising from the button and fading out —
              // "effect released" flourish, purely cosmetic. clipBehavior
              // is none so it can float above the footer bar.
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _helpRisingController,
                  builder: (_, __) {
                    final r = _helpRisingController.value;
                    if (r == 0) return const SizedBox.shrink();
                    final dy = -40.0 * r;
                    final opacity = (0.7 * (1.0 - r)).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Opacity(
                        opacity: opacity,
                        child: Icon(
                          PhosphorIconsFill.firstAid,
                          size: 22,
                          color: Colors.red.shade500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ColorFilter _saturationFilter(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return ColorFilter.matrix(<double>[
      r + (1 - r) * s, g - g * s,       b - b * s,       0, 0,
      r - r * s,       g + (1 - g) * s, b - b * s,       0, 0,
      r - r * s,       g - g * s,       b + (1 - b) * s, 0, 0,
      0,               0,               0,               1, 0,
    ]);
  }
}

class _PendingNotification {
  final PhosphorIconData icon;
  final String text;
  const _PendingNotification({required this.icon, required this.text});
}

class _TopNotification extends StatefulWidget {
  final PhosphorIconData icon;
  final String text;
  final VoidCallback onDismiss;

  const _TopNotification({required this.icon, required this.text, required this.onDismiss});

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24, right: 24,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC956),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 28, color: const Color(0xFF1B3A4B)),
                const SizedBox(height: 6),
                Text(
                  widget.text,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B3A4B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderGif extends StatelessWidget {
  const _LoaderGif();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/loading_loop.gif',
      width: 95,
      height: 95,
      fit: BoxFit.cover,
    );
  }
}

/// Renders the reference photo so it matches the exact crop of the selected
/// difficulty. Mirrors the math in `PuzzleEngine._buildPieceWidget` — the
/// visible area is the engine's `boardWidth × boardHeight`, and the source
/// image is scaled to `board / cW × board / cH` so that only the crop rect
/// fills the viewport.
class _ReferenceCropView extends StatelessWidget {
  final LocationModel location;
  final int difficulty;
  const _ReferenceCropView({
    required this.location,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = location.getImageForDifficulty(difficulty);
    // Mirror the engine's piece math 1:1 (see `PuzzleEngine._buildPieceWidget`).
    // Pre-rendered crops are already baked in at the admin side, so the logical
    // crop rect is [0,0,1,1] — the OverflowBox/cover path still renders them
    // at board size. Using `BoxFit.contain` here would letterboxe the image
    // whenever its aspect didn't match the viewport, so pieces sampled from
    // `cover` and the reference would disagree.
    final crop = location.hasPreRenderedCrop(difficulty)
        ? const [0.0, 0.0, 1.0, 1.0]
        : location.getCropForDifficulty(difficulty);
    final cX = crop[0], cY = crop[1], cW = crop[2], cH = crop[3];

    return LayoutBuilder(
      builder: (ctx, box) {
        final imgW = box.maxWidth / cW;
        final imgH = box.maxHeight / cH;
        return ClipRect(
          child: OverflowBox(
            maxWidth: imgW,
            maxHeight: imgH,
            alignment: Alignment(
              cW >= 1 ? 0 : (2 * cX / (1 - cW) - 1),
              cH >= 1 ? 0 : (2 * cY / (1 - cH) - 1),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: imgW,
              height: imgH,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
