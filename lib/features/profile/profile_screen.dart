import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/trophy_model.dart';
import 'package:chile_puzzle/core/services/audio_service.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/core/services/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chile_puzzle/features/leaderboard/leaderboard_screen.dart';
import 'package:chile_puzzle/main.dart';

class ProfileScreen extends StatefulWidget {
  final GameConfig config;
  final List<LocationModel> allLocations;

  const ProfileScreen({super.key, required this.config, required this.allLocations});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;
    final allLocations = widget.allLocations;
    final config = widget.config;
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
                Builder(builder: (ctx) {
                  final w = MediaQuery.of(ctx).size.width * 0.28;
                  return Image.asset(
                    'assets/girl_cat_standing.png',
                    width: w,
                    height: w,
                    fit: BoxFit.contain,
                  );
                }),
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
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    final newLocale = langCode == 'es' ? const Locale('en') : const Locale('es');
                    ChilePuzzleApp.setLocale(context, newLocale);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsBold.globe, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          langCode == 'es' ? 'English' : 'Español',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
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
          const SizedBox(height: 16),

          // Ranking button
          MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
              icon: const Icon(PhosphorIconsBold.listNumbers, size: 20),
              label: Text(langCode == 'es' ? 'Ver ranking' : 'View ranking'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppTheme.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Trophies button → opens modal
          GestureDetector(
            onTap: () => _showTrophiesModal(context, config, progress, langCode, l10n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsFill.trophy, size: 22, color: AppTheme.trophyGold),
                  const SizedBox(width: 12),
                  Text(
                    l10n?.trophies ?? 'Trophies',
                    style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
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
                  const SizedBox(width: 8),
                  Icon(PhosphorIconsBold.caretRight, size: 16, color: Colors.grey.shade400),
                ],
              ),
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

          // Backup & Restore button
          OutlinedButton.icon(
            onPressed: () => showBackupSheet(context),
            icon: const Icon(PhosphorIconsBold.cloudArrowUp, size: 18),
            label: Text(l10n?.backupAndRestore ?? 'Backup & restore'),
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

void showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog>
    with SingleTickerProviderStateMixin {
  // Drives the in-settings preview box so Flash and Shimmer play once on
  // selection — matches what the player will actually see mid-puzzle.
  late final AnimationController _shimmerPreviewController;

  @override
  void initState() {
    super.initState();
    _shimmerPreviewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _shimmerPreviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final es = langCode == 'es';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsFill.gear, size: 22, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    es ? 'Ajustes' : 'Settings',
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(PhosphorIconsBold.x, size: 20, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Language row — taps toggle ES ↔ EN
              _settingRow(
                icon: PhosphorIconsFill.globe,
                iconColor: AppTheme.accentBlue,
                label: es ? 'Idioma' : 'Language',
                subtitle: es ? 'Español' : 'English',
                trailing: Icon(
                  PhosphorIconsBold.arrowsLeftRight,
                  size: 22,
                  color: Colors.grey.shade400,
                ),
                onTap: () {
                  final newLocale = es ? const Locale('en') : const Locale('es');
                  ChilePuzzleApp.setLocale(context, newLocale);
                },
              ),
              Divider(color: Colors.grey.shade200, height: 1),
              _toggleRow(
                icon: AudioService.isMuted
                    ? PhosphorIconsFill.speakerSlash
                    : PhosphorIconsFill.speakerHigh,
                iconColor: AppTheme.accentGreen,
                label: es ? 'Sonido' : 'Sound',
                subtitle: es ? 'Efectos de sonido del juego' : 'Game sound effects',
                value: !AudioService.isMuted,
                onChanged: (v) async {
                  await AudioService.toggleMute();
                  setState(() {});
                },
              ),
              Divider(color: Colors.grey.shade200, height: 1),
              // Piece-placement feedback: 3-mode preference (no penalty).
              _shimmerModeRow(es: es),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerModeRow({required bool es}) {
    final mode = SettingsService.shimmerMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            es ? 'Brillo' : 'Shine',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            es ? 'Efecto al acertar la pieza' : 'Effect on correct placement',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          // Tapping replays the effect on the button itself — pill-shaped so
          // the diagonal sweep has real canvas, not just a 44px circle.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _shimmerAvatar(
                icon: PhosphorIconsFill.lightning,
                mode: ShimmerMode.flash,
                current: mode,
                selectedBg: Colors.indigo.shade500,
                onTap: () async {
                  await SettingsService.setShimmerMode(ShimmerMode.flash);
                  setState(() {});
                  _previewShimmer();
                },
              ),
              const SizedBox(width: 14),
              _shimmerAvatar(
                icon: PhosphorIconsFill.sparkle,
                mode: ShimmerMode.shimmer,
                current: mode,
                selectedBg: Colors.indigo.shade500,
                onTap: () async {
                  await SettingsService.setShimmerMode(ShimmerMode.shimmer);
                  setState(() {});
                  _previewShimmer();
                },
              ),
              const SizedBox(width: 14),
              _shimmerAvatar(
                icon: PhosphorIconsBold.prohibit,
                mode: ShimmerMode.off,
                current: mode,
                selectedBg: Colors.grey.shade600,
                onTap: () async {
                  await SettingsService.setShimmerMode(ShimmerMode.off);
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _previewShimmer() {
    _shimmerPreviewController.forward(from: 0.0);
  }

  Widget _shimmerAvatar({
    required IconData icon,
    required ShimmerMode mode,
    required ShimmerMode current,
    required Color selectedBg,
    required VoidCallback onTap,
  }) {
    final selected = mode == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _shimmerPreviewController,
        builder: (_, __) {
          final t = selected ? _shimmerPreviewController.value : 0.0;
          final animating = selected && mode != ShimmerMode.off && t > 0;
          BoxDecoration deco;
          if (animating && mode == ShimmerMode.flash) {
            // Whole-button pulse: lerp selectedBg → white → selectedBg.
            final pulse =
                (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
            deco = BoxDecoration(
              color: Color.lerp(selectedBg, Colors.white, pulse * 0.9),
              borderRadius: BorderRadius.circular(14),
            );
          } else if (animating && mode == ShimmerMode.shimmer) {
            // Diagonal band across the whole pill.
            deco = BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 3.0 * t, -1.0 + 3.0 * t),
                end: Alignment(-0.5 + 3.0 * t, -0.5 + 3.0 * t),
                colors: [selectedBg, Colors.white, selectedBg],
              ),
            );
          } else {
            deco = BoxDecoration(
              color: selected ? selectedBg : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            );
          }
          return Container(
            width: 72,
            height: 48,
            decoration: deco,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
          );
        },
      ),
    );
  }

  Widget _toggleRow({
    required PhosphorIconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    int? penalty,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (penalty != null && value) ...[
              Text(
                '-$penalty',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(
              value ? PhosphorIconsFill.checkCircle : PhosphorIconsBold.circle,
              size: 28,
              color: value ? AppTheme.accentBlue : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow({
    required PhosphorIconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

void _showTrophiesModal(BuildContext context, GameConfig config, dynamic progress, String langCode, AppLocalizations? l10n) {
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsFill.trophy, size: 22, color: AppTheme.trophyGold),
                const SizedBox(width: 8),
                Text(
                  l10n?.trophies ?? 'Trophies',
                  style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 20),
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
        ],
      ),
    ),
  );
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
      builder: (_, controller) => Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
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
            text: l10n?.photoCredits ?? 'Photography: Sabino & Xime',
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'v1.10.0',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Builder(builder: (ctx) {
                final w = MediaQuery.of(ctx).size.width * 0.42;
                return Image.asset(
                  'assets/bottom-right-about.png',
                  width: w,
                  fit: BoxFit.contain,
                );
              }),
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
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
    case 'plant': return PhosphorIconsFill.plant;
    case 'skull': return PhosphorIconsFill.skull;
    case 'flame': return PhosphorIconsFill.flame;
    case 'spiral': return PhosphorIconsFill.spiral;
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
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
                    trophy.getLocalizedName(langCode),
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
      ),
    );
  }
}

// ============================================================
// BACKUP & RESTORE SHEET
// ============================================================
void showBackupSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BackupSheet(),
  );
}

class _BackupSheet extends StatefulWidget {
  const _BackupSheet();

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  // Backup tab state
  String? _code;
  String? _expiresAt;
  bool _creating = false;
  bool _sendingEmail = false;
  bool _emailSent = false;
  final TextEditingController _emailCtrl = TextEditingController();

  // Restore tab state
  final TextEditingController _codeCtrl = TextEditingController();
  bool _restoring = false;
  String? _restoreError;

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _formatCode(String code) =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  String _formatDate(String iso, String langCode) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final months = langCode == 'es'
          ? ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']
          : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _createBackup() async {
    setState(() => _creating = true);
    final result = await MockBackend.createProgressBackup(
      GameProgressService.progressAsJson(),
    );
    if (!mounted) return;
    setState(() {
      _creating = false;
      if (result != null) {
        _code = result.code;
        _expiresAt = result.expiresAt;
      }
    });
    if (result == null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.backupFailed ?? 'Could not create backup')),
      );
    }
  }

  Future<void> _copyCode() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _formatCode(_code!)));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.codeCopied ?? 'Code copied'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _emailCode() async {
    if (_code == null || _sendingEmail || _emailSent) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return;
    setState(() => _sendingEmail = true);
    final langCode = Localizations.localeOf(context).languageCode;
    final ok = await MockBackend.emailProgressBackup(
      code: _code!,
      email: email,
      lang: langCode == 'es' ? 'es' : 'en',
    );
    if (!mounted) return;
    setState(() {
      _sendingEmail = false;
      _emailSent = ok;
    });
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      Navigator.pop(context); // close the backup sheet
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.emailSent ?? 'Email sent')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.emailFailed ?? 'Could not send email')),
      );
    }
  }

  Future<void> _restore() async {
    final raw = _codeCtrl.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.length != 8) {
      setState(() => _restoreError = AppLocalizations.of(context)?.backupCodeInvalid ?? 'Invalid code');
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.restoreConfirmTitle ?? 'Restore progress?'),
        content: Text(l10n?.restoreConfirmBody ?? 'This will overwrite your current progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n?.restoreAction ?? 'Restore'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _restoring = true;
      _restoreError = null;
    });
    final payload = await MockBackend.fetchProgressBackup(raw);
    if (!mounted) return;
    if (payload == null) {
      setState(() {
        _restoring = false;
        _restoreError = l10n?.backupCodeInvalid ?? 'Invalid or expired code';
      });
      return;
    }
    try {
      await GameProgressService.replaceProgressFromJson(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _restoreError = l10n?.backupCodeInvalid ?? 'Invalid or expired code';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    Navigator.pop(context); // close the sheet
    // Pop the profile screen as well so the map reloads with new progress.
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.restoreSuccess ?? 'Progress restored')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(PhosphorIconsFill.cloudArrowUp, size: 22, color: AppTheme.seedColor),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.backupAndRestore ?? 'Backup & restore',
                    style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(PhosphorIconsBold.x, size: 20, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tab,
                labelColor: AppTheme.seedColor,
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: AppTheme.seedColor,
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: l10n?.backupProgress ?? 'Backup'),
                  Tab(text: l10n?.restoreProgress ?? 'Restore'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildBackupTab(l10n, langCode),
                    _buildRestoreTab(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupTab(AppLocalizations? l10n, String langCode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.backupIntro ?? 'Save your progress with a short code.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_code == null) ...[
            FilledButton.icon(
              onPressed: _creating ? null : _createBackup,
              icon: _creating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(PhosphorIconsBold.plusCircle, size: 18),
              label: Text(l10n?.generateBackupCode ?? 'Generate code'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.seedColor.withValues(alpha: 0.06),
                border: Border.all(color: AppTheme.seedColor.withValues(alpha: 0.3), width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _formatCode(_code!),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.seedColor,
                      letterSpacing: 3,
                    ),
                  ),
                  if (_expiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      (l10n?.backupExpiresOn(_formatDate(_expiresAt!, langCode))) ??
                          'Valid until ${_formatDate(_expiresAt!, langCode)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyCode,
              icon: const Icon(PhosphorIconsBold.copy, size: 16),
              label: Text(l10n?.copyCode ?? 'Copy code'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: l10n?.emailPlaceholder ?? 'you@email.com',
                prefixIcon: const Icon(PhosphorIconsBold.envelope, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_sendingEmail || _emailSent) ? null : _emailCode,
              icon: _sendingEmail
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(PhosphorIconsBold.paperPlaneTilt, size: 16),
              label: Text(l10n?.emailCode ?? 'Email it to me'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.backupPrivacyWarning ?? 'Anyone with this code can restore your progress.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestoreTab(AppLocalizations? l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.enterBackupCode ?? 'Enter your code',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3),
            maxLength: 9, // 8 chars + hyphen
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            ],
            decoration: InputDecoration(
              hintText: l10n?.backupCodePlaceholder ?? 'XXXX-XXXX',
              hintStyle: GoogleFonts.spaceGrotesk(fontSize: 22, letterSpacing: 3, color: Colors.grey.shade300),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: '',
              errorText: _restoreError,
            ),
            onChanged: (_) {
              if (_restoreError != null) setState(() => _restoreError = null);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _restoring ? null : _restore,
            icon: _restoring
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(PhosphorIconsBold.downloadSimple, size: 18),
            label: Text(l10n?.restoreAction ?? 'Restore'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ),
    );
  }
}
