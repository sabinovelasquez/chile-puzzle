import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/features/leaderboard/initials_input.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  int? _lastSubmittedRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() { _isLoading = true; });
    final entries = await MockBackend.fetchLeaderboard();
    if (mounted) {
      setState(() { _entries = entries; _isLoading = false; });
    }
  }

  Future<void> _submitScore() async {
    final langCode = Localizations.localeOf(context).languageCode;
    String? initials = GameProgressService.leaderboardInitials;

    if (initials == null) {
      initials = await showInitialsInput(context);
      if (initials == null) return; // cancelled
      await GameProgressService.setLeaderboardInitials(initials);
    }

    final progress = GameProgressService.progress;
    final result = await MockBackend.submitScore(
      initials: initials,
      totalPoints: progress.totalPoints,
      puzzlesCompleted: progress.completedCount,
    );

    if (result != null && mounted) {
      setState(() { _lastSubmittedRank = result['rank']; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'es'
              ? '¡Posición #${result['rank']}!'
              : 'Ranked #${result['rank']}!'),
        ),
      );
      _loadLeaderboard();
    }
  }

  Future<void> _changeInitials() async {
    final current = GameProgressService.leaderboardInitials;
    final initials = await showInitialsInput(context, currentInitials: current);
    if (initials != null) {
      await GameProgressService.setLeaderboardInitials(initials);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final initials = GameProgressService.leaderboardInitials;

    return Scaffold(
      appBar: AppBar(
        title: Text(langCode == 'es' ? 'Ranking' : 'Leaderboard'),
        actions: [
          if (initials != null)
            TextButton(
              onPressed: _changeInitials,
              child: Text(initials, style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w800,
              )),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsBold.trophy, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                langCode == 'es' ? 'Sin puntajes aún' : 'No scores yet',
                                style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                langCode == 'es' ? '¡Sé el primero!' : 'Be the first!',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLeaderboard,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final rank = entry['rank'] as int;
                              final isHighlighted = _lastSubmittedRank == rank &&
                                  entry['initials'] == initials;
                              return _LeaderboardRow(
                                rank: rank,
                                initials: entry['initials'] as String,
                                points: entry['totalPoints'] as int,
                                puzzles: entry['puzzlesCompleted'] as int,
                                highlighted: isHighlighted,
                              );
                            },
                          ),
                        ),
                ),
                // Submit button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16, 8, 16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitScore,
                      icon: const Icon(PhosphorIconsBold.paperPlaneTilt, size: 18),
                      label: Text(langCode == 'es' ? 'Enviar puntaje' : 'Submit score'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String initials;
  final int points;
  final int puzzles;
  final bool highlighted;

  const _LeaderboardRow({
    required this.rank,
    required this.initials,
    required this.points,
    required this.puzzles,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final medalColors = {1: AppTheme.trophyGold, 2: Colors.grey.shade400, 3: const Color(0xFFCD7F32)};

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.accentBlue.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: isTop3
                ? Icon(PhosphorIconsFill.medal, size: 24, color: medalColors[rank])
                : Text(
                    '#$rank',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade500,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Initials
          Container(
            width: 48, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.seedColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$points pts',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.trophyGold,
                  ),
                ),
                Text(
                  '$puzzles puzzles',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
