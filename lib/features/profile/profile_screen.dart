import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/models/trophy_model.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/puzzle/icon_mapping.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  final GameConfig config;

  const ProfileScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.profile ?? 'Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(
                  value: '${progress.totalPoints}',
                  label: l10n?.totalPoints ?? 'Points',
                  color: AppTheme.trophyGold,
                ),
                _StatColumn(
                  value: '${progress.completedCount}',
                  label: l10n?.puzzlesCompleted ?? 'Puzzles',
                ),
                _StatColumn(
                  value: progress.fastestTime != null
                      ? '${progress.fastestTime}s'
                      : '—',
                  label: l10n?.bestTime ?? 'Best Time',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Trophies header
          Text(
            l10n?.trophies ?? 'Trophies',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Trophy grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
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
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatColumn({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned
            ? AppTheme.trophyGold.withOpacity(0.08)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEarned
              ? AppTheme.trophyGold.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            mapIcon(trophy.icon),
            size: 28,
            color: isEarned ? AppTheme.trophyGold : Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            isEarned ? trophy.getLocalizedName(langCode) : '???',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isEarned ? null : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isEarned) ...[
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () {
                Share.share('${trophy.getLocalizedName(langCode)} #ChilePuzzleExplorer');
              },
              child: const Icon(Icons.share, size: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
