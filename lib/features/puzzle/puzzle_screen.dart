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

class PuzzleScreen extends StatefulWidget {
  final LocationModel location;
  final int difficulty;
  final GameConfig gameConfig;
  final List<LocationModel> allLocations;

  const PuzzleScreen({
    super.key,
    required this.location,
    required this.difficulty,
    required this.gameConfig,
    required this.allLocations,
  });

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  CompletionResult? _result;
  bool _completed = false;
  bool _showDrawer = true;
  bool _firstDrawerShow = true;
  bool _showReference = false;
  bool _tipsVisible = false;

  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _moveCount = ValueNotifier(0);
  final ValueNotifier<bool> _imageLoaded = ValueNotifier(false);

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
  }

  @override
  void dispose() {
    _timerSub.cancel();
    super.dispose();
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
        body: Column(
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
                  ),
                  // Loading overlay
                  ValueListenableBuilder<bool>(
                    valueListenable: _imageLoaded,
                    builder: (_, loaded, __) {
                      if (loaded) return const SizedBox.shrink();
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                  // Reference image overlay + button (only after image loads)
                  ValueListenableBuilder<bool>(
                    valueListenable: _imageLoaded,
                    builder: (_, loaded, __) {
                      if (!loaded || _completed || !SettingsService.referenceImage) {
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
                                  child: CachedNetworkImage(
                                    imageUrl: widget.location
                                        .getImageForDifficulty(widget.difficulty),
                                    fit: BoxFit.contain,
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => setState(() => _showReference = !_showReference),
                              child: Container(
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
                            ),
                          ),
                        ],
                      );
                    },
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
                  if (_completed && !_showDrawer) ...[
                    // Lightbulb toggle — top-right
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _tipsVisible = !_tipsVisible),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _tipsVisible
                                ? PhosphorIconsFill.lightbulb
                                : PhosphorIconsBold.lightbulb,
                            size: 20,
                            color: _tipsVisible ? AppTheme.trophyGold : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Tip card — bottom
                    if (_tipsVisible)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              14,
                              widget.location.showSilhouette ? 120 : 14,
                              14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.location.getLocalizedTipForDifficulty(
                                langCode,
                                widget.difficulty,
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Silhouette — bottom-right, independent of the tip toggle
                    if (widget.location.showSilhouette)
                      Positioned(
                        right: 8,
                        bottom: _tipsVisible ? 48 : 12,
                        child: IgnorePointer(
                          child: SizedBox(
                            width: 110,
                            height: 89,
                            child: SvgPicture.asset(
                              'assets/girl_cat.svg',
                              fit: BoxFit.contain,
                            ),
                          ),
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
            // Bottom footer — always visible
            Container(
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
                          child: Text(
                            widget.location.getLocalizedName(langCode),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ValueListenableBuilder<int>(
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
                        IconButton(
                          onPressed: () async {
                            if (await _onWillPop()) {
                              if (mounted) Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(PhosphorIconsBold.x, size: 20, color: Colors.white70),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
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
              color: const Color(0xFF1B3A4B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 28, color: AppTheme.trophyGold),
                const SizedBox(height: 6),
                Text(
                  widget.text,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
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
