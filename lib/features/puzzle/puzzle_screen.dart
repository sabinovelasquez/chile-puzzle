import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:chile_puzzle/core/services/audio_service.dart';
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

  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _moveCount = ValueNotifier(0);
  final ValueNotifier<bool> _imageLoaded = ValueNotifier(false);

  late final StreamSubscription _timerSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _timerSub = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted && _stopwatch.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerSub.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      AudioService.playPuzzleComplete();
    }

    setState(() {
      _result = result;
      _completed = true;
      _showDrawer = true;
    });

    if (result.newTrophies.isNotEmpty && mounted) {
      final langCode = Localizations.localeOf(context).languageCode;
      for (final trophy in result.newTrophies) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(PhosphorIconsFill.trophy, size: 20, color: AppTheme.trophyGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trophy.getLocalizedName(langCode),
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1B3A4B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final secs = _stopwatch.elapsed.inSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    final topPadding = MediaQuery.of(context).padding.top;

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
            // Top bar — hidden on completion via AnimatedContainer
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _completed ? 0 : topPadding + 48,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(color: Colors.white),
              child: Container(
                padding: EdgeInsets.fromLTRB(16, topPadding + 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.location.getLocalizedName(langCode),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _moveCount,
                      builder: (_, moves, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_stopwatch.isRunning)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(PhosphorIconsBold.pause, size: 12, color: Colors.grey.shade600),
                              ),
                            Text(
                              '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}  ·  $moves mov',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
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
                      icon: Icon(PhosphorIconsBold.x, size: 20, color: Colors.grey.shade700),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
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
                  // Bottom stats bar — always visible when completed, fixed height
                  if (_completed)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(16, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
                        color: AppTheme.seedColor,
                        child: Row(
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
                              child: IgnorePointer(
                                ignoring: _showDrawer,
                                child: FloatingActionButton.small(
                                  onPressed: () => setState(() => _showDrawer = true),
                                  backgroundColor: AppTheme.accentBlue,
                                  child: const Icon(PhosphorIconsBold.trophy, size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Completion drawer
                  if (_completed && _showDrawer)
                    CompletionDrawer(
                      location: widget.location,
                      result: _result,
                      animate: _firstDrawerShow,
                      onHide: () => setState(() {
                        _showDrawer = false;
                        _firstDrawerShow = false;
                      }),
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
