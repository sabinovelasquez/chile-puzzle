import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
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
    setState(() {
      _result = result;
      _completed = true;
    });

    // Show trophies as snackbars
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.location.getLocalizedName(langCode),
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            PuzzleEngine(
              location: widget.location,
              difficulty: widget.difficulty,
              onCompleted: _handleCompletion,
            ),
            if (_completed && _showDrawer)
              CompletionDrawer(
                location: widget.location,
                result: _result,
                onHide: () => setState(() => _showDrawer = false),
              ),
            // FAB to re-show results when drawer is hidden
            if (_completed && !_showDrawer)
              Positioned(
                bottom: 16, right: 16,
                child: FloatingActionButton.small(
                  onPressed: () => setState(() => _showDrawer = true),
                  backgroundColor: AppTheme.accentBlue,
                  child: const Icon(PhosphorIconsBold.trophy, size: 20, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
