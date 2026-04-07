import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/trophy_model.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
          const SizedBox(height: 16),

          // Progress bar
          Builder(builder: (_) {
            final totalDifficulties = allLocations.fold<int>(
              0, (sum, loc) => sum + (loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels.length : 1),
            );
            final completedCount = progress.completedPuzzles.length;
            final progressPercent = totalDifficulties > 0
                ? (completedCount / totalDifficulties * 100).round()
                : 0;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langCode == 'es' ? 'Progreso total' : 'Total progress',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$progressPercent%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalDifficulties > 0 ? completedCount / totalDifficulties : 0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accentBlue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langCode == 'es'
                            ? '$completedCount niveles hechos'
                            : '$completedCount levels done',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        '$totalDifficulties total',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
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
          const SizedBox(height: 24),

          // New locations banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.mapTrifold, size: 22, color: AppTheme.accentBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n?.newLocationsWeekly ?? 'New locations every week — keep exploring!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppTheme.accentBlue, fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About button
          OutlinedButton.icon(
            onPressed: () => _showAboutDialog(context, l10n, langCode),
            icon: const Icon(PhosphorIconsBold.info, size: 18),
            label: Text(l10n?.about ?? 'About'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),

          // Clear progress button
          TextButton.icon(
            onPressed: () => _showClearProgressDialog(context, l10n, langCode),
            icon: const Icon(PhosphorIconsBold.trash, size: 16),
            label: Text(l10n?.clearProgress ?? 'Clear progress'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              textStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

void _showClearProgressDialog(BuildContext context, AppLocalizations? l10n, String langCode) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        l10n?.clearProgress ?? 'Clear progress',
        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
      ),
      content: Text(
        l10n?.clearProgressWarning ?? 'This will delete all your points, trophies and progress. Are you sure?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        TextButton(
          onPressed: () async {
            await GameProgressService.reset();
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(
            l10n?.delete ?? 'Delete',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

void _showAboutDialog(BuildContext context, AppLocalizations? l10n, String langCode) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(
            child: Text(
              'Zoom-In Chile',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.seedColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n?.aboutDescription ?? '',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, height: 1.6, color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://sabino.cl'), mode: LaunchMode.externalApplication),
            child: Text(
              l10n?.aboutSignature ?? '— Sabino',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.seedColor,
                decoration: TextDecoration.underline, decorationColor: AppTheme.seedColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
          _CreditRow(
            icon: PhosphorIconsFill.camera,
            iconColor: AppTheme.accentBlue,
            text: l10n?.photoCredits ?? 'Photography: Sabino & Ximena',
            url: 'https://sabino.cl',
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'v1.1.0',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CreditRow extends StatelessWidget {
  final PhosphorIconData icon;
  final Color iconColor;
  final String text;
  final String? url;

  const _CreditRow({required this.icon, required this.iconColor, required this.text, this.url});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: url != null ? AppTheme.accentBlue : Colors.grey.shade600,
              decoration: url != null ? TextDecoration.underline : null,
              decorationColor: AppTheme.accentBlue,
            ),
          ),
        ),
        if (url != null)
          Icon(PhosphorIconsBold.arrowSquareOut, size: 14, color: Colors.grey.shade400),
      ],
    );
    if (url != null) {
      return GestureDetector(
        onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
        child: row,
      );
    }
    return row;
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
    case 'trophy': return PhosphorIconsFill.trophy;
    case 'emoji_events': return PhosphorIconsFill.trophy;
    case 'star': return PhosphorIconsFill.star;
    case 'bolt': return PhosphorIconsFill.lightning;
    case 'lightning': return PhosphorIconsFill.lightning;
    case 'timer': return PhosphorIconsFill.timer;
    case 'diamond': return PhosphorIconsFill.diamond;
    case 'flag': return PhosphorIconsFill.flag;
    case 'puzzle_piece': return PhosphorIconsFill.puzzlePiece;
    case 'mountains': return PhosphorIconsFill.mountains;
    case 'hiking': return PhosphorIconsFill.mountains;
    case 'landscape': return PhosphorIconsFill.mountains;
    case 'compass': return PhosphorIconsFill.compass;
    case 'explore': return PhosphorIconsFill.compass;
    case 'medal': return PhosphorIconsFill.medal;
    case 'crown': return PhosphorIconsFill.crown;
    case 'fire': return PhosphorIconsFill.fire;
    case 'rocket': return PhosphorIconsFill.rocket;
    case 'eye': return PhosphorIconsFill.eye;
    case 'globe': return PhosphorIconsFill.globe;
    case 'map_pin': return PhosphorIconsFill.mapPin;
    case 'camera': return PhosphorIconsFill.camera;
    case 'heart': return PhosphorIconsFill.heart;
    case 'shield': return PhosphorIconsFill.shield;
    case 'target': return PhosphorIconsFill.target;
    case 'binoculars': return PhosphorIconsFill.binoculars;
    case 'path': return PhosphorIconsFill.path;
    case 'sun': return PhosphorIconsFill.sun;
    case 'map_trifold': return PhosphorIconsFill.mapTrifold;
    case 'hand_pointing': return PhosphorIconsFill.handPointing;
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
