import 'package:flutter/material.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chile_puzzle/features/puzzle/puzzle_engine.dart';

class PuzzleScreen extends StatefulWidget {
  final LocationModel location;
  final int gridRows;
  final int gridCols;

  const PuzzleScreen({
    super.key,
    required this.location,
    required this.gridRows,
    required this.gridCols,
  });

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.getLocalizedName(langCode)),
      ),
      body: SafeArea(
        child: PuzzleEngine(
          location: widget.location,
          rows: widget.gridRows,
          cols: widget.gridCols,
        ),
      ),
    );
  }
}
