import 'package:flutter/material.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
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
            if (_completed)
              CompletionDrawer(
                location: widget.location,
                result: _result,
              ),
          ],
        ),
      ),
    );
  }
}
