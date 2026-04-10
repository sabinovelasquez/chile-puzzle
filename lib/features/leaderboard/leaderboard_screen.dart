import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';

class LeaderboardScreen extends StatefulWidget {
  /// When both [locationId] and [difficulty] are provided, the screen
  /// displays the per-location top 25 instead of the global leaderboard.
  final String? locationId;
  final int? difficulty;
  final String? locationName;

  const LeaderboardScreen({
    super.key,
    this.locationId,
    this.difficulty,
    this.locationName,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  bool _confettiFired = false;

  bool get _isPerLocation =>
      widget.locationId != null && widget.difficulty != null;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() { _isLoading = true; });
    List<Map<String, dynamic>> entries;
    if (_isPerLocation) {
      final result = await MockBackend.fetchLocationLeaderboard(
        widget.locationId!,
        widget.difficulty!,
      );
      entries = result.entries;
    } else {
      entries = await MockBackend.fetchLeaderboard(limit: 10);
    }
    if (mounted) {
      setState(() { _entries = entries; _isLoading = false; });
      if (!_confettiFired && entries.isNotEmpty) {
        _confettiFired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _launchConfetti());
      }
    }
  }

  static const Map<int, String> _diffLabelsEs = {
    3: 'Fácil', 4: 'Normal', 5: 'Difícil', 6: 'Experto',
  };
  static const Map<int, String> _diffLabelsEn = {
    3: 'Easy', 4: 'Normal', 5: 'Hard', 6: 'Expert',
  };

  void _launchConfetti() {
    const colors = [Color(0xffbb0000), Color(0xffffffff)];
    const frameTime = 1000 ~/ 24;
    const total = 2 * 1000 ~/ frameTime;
    int progress = 0;
    ConfettiController? controller1;
    ConfettiController? controller2;
    bool isDone = false;

    Timer.periodic(const Duration(milliseconds: frameTime), (timer) {
      progress++;
      if (progress >= total) {
        timer.cancel();
        isDone = true;
        return;
      }
      if (!mounted) { timer.cancel(); return; }
      if (controller1 == null) {
        controller1 = Confetti.launch(context,
          options: const ConfettiOptions(particleCount: 2, angle: 60, spread: 55, x: 0, colors: colors),
          onFinished: (overlayEntry) { if (isDone) overlayEntry.remove(); },
        );
      } else {
        controller1!.launch();
      }
      if (controller2 == null) {
        controller2 = Confetti.launch(context,
          options: const ConfettiOptions(particleCount: 2, angle: 120, spread: 55, x: 1, colors: colors),
          onFinished: (overlayEntry) { if (isDone) overlayEntry.remove(); },
        );
      } else {
        controller2!.launch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;

    String title;
    String? subtitle;
    if (_isPerLocation) {
      title = widget.locationName ?? (langCode == 'es' ? 'Ranking' : 'Leaderboard');
      final labels = langCode == 'es' ? _diffLabelsEs : _diffLabelsEn;
      subtitle = labels[widget.difficulty] ?? '${widget.difficulty} col';
    } else {
      title = langCode == 'es' ? 'Ranking' : 'Leaderboard';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
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
                      return _LeaderboardRow(
                        rank: entry['rank'] as int,
                        initials: entry['initials'] as String,
                        points: (entry['totalPoints'] ?? entry['points']) as int,
                      );
                    },
                  ),
                ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String initials;
  final int points;

  const _LeaderboardRow({
    required this.rank,
    required this.initials,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final medalColors = {1: AppTheme.trophyGold, 2: Colors.grey.shade400, 3: const Color(0xFFCD7F32)};

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Container(
              height: 36,
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
          ),
          const SizedBox(width: 16),
          Text(
            '$points pts',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.trophyGold,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
