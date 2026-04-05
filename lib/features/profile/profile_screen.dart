import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/trophy_model.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  final GameConfig config;
  final List<LocationModel> allLocations;

  const ProfileScreen({super.key, required this.config, required this.allLocations});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;
    final unlockedCount = allLocations.where((loc) {
      return GameProgressService.isLocationUnlocked(loc);
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.profile ?? 'Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(PhosphorIconsFill.mapTrifold, size: 40, color: AppTheme.accentBlue),
                ),
                const SizedBox(height: 16),
                Text(
                  langCode == 'es' ? 'Mi Perfil de Explorador' : 'My Explorer Profile',
                  style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  langCode == 'es'
                      ? '$unlockedCount/${allLocations.length} ubicaciones descubiertas'
                      : '$unlockedCount/${allLocations.length} locations discovered',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Stats grid 2x2
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                icon: PhosphorIconsFill.star,
                iconColor: AppTheme.trophyGold,
                value: '${progress.totalPoints}',
                label: l10n?.totalPoints ?? 'Total Points',
              ),
              _StatCard(
                icon: PhosphorIconsFill.puzzlePiece,
                iconColor: AppTheme.accentGreen,
                value: '${progress.completedCount}',
                label: l10n?.puzzlesCompleted ?? 'Puzzles Done',
              ),
              _StatCard(
                icon: PhosphorIconsFill.timer,
                iconColor: AppTheme.accentBlue,
                value: progress.fastestTime != null ? '${progress.fastestTime}s' : '--',
                label: l10n?.bestTime ?? 'Best Time',
              ),
              _StatCard(
                icon: PhosphorIconsFill.lockOpen,
                iconColor: AppTheme.accentOrange,
                value: '$unlockedCount/${allLocations.length}',
                label: langCode == 'es' ? 'Ubicaciones' : 'Locations',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Trophies header
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsFill.trophy, size: 22, color: AppTheme.trophyGold),
                const SizedBox(width: 8),
                Text(
                  l10n?.trophies ?? 'Trophies',
                  style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${progress.earnedTrophyIds.length}/${config.trophies.length}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Trophy grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: config.trophies.length,
            itemBuilder: (context, index) {
              final trophy = config.trophies[index];
              final isEarned = progress.earnedTrophyIds.contains(trophy.id);
              return _TrophyCard(
                trophy: trophy,
                isEarned: isEarned,
                langCode: langCode,
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final PhosphorIconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

PhosphorIconData _trophyIcon(String iconName) {
  switch (iconName) {
    case 'hiking': return PhosphorIconsFill.mountains;
    case 'explore': return PhosphorIconsFill.compass;
    case 'landscape': return PhosphorIconsFill.mountains;
    case 'emoji_events': return PhosphorIconsFill.trophy;
    case 'bolt': return PhosphorIconsFill.lightning;
    case 'timer': return PhosphorIconsFill.timer;
    case 'diamond': return PhosphorIconsFill.diamond;
    case 'flag': return PhosphorIconsFill.flag;
    case 'puzzle_piece': return PhosphorIconsFill.puzzlePiece;
    case 'star': return PhosphorIconsFill.star;
    default: return PhosphorIconsFill.trophy;
  }
}

class _TrophyCard extends StatelessWidget {
  final TrophyModel trophy;
  final bool isEarned;
  final String langCode;

  const _TrophyCard({
    required this.trophy,
    required this.isEarned,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isEarned
            ? Border.all(color: AppTheme.trophyGold.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Stack(
        children: [
          if (!isEarned)
            Positioned(
              top: 0, right: 0,
              child: Icon(PhosphorIconsBold.lock, size: 14, color: Colors.grey.shade300),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _trophyIcon(trophy.icon),
                  size: 32,
                  color: isEarned ? AppTheme.trophyGold : Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Text(
                  isEarned ? trophy.getLocalizedName(langCode) : trophy.getLocalizedName(langCode),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isEarned ? AppTheme.seedColor : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  trophy.getLocalizedDescription(langCode),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
