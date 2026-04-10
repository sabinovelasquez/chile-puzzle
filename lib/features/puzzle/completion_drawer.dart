import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/ads/ad_service.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/features/leaderboard/initials_input.dart';
import 'package:chile_puzzle/features/leaderboard/leaderboard_screen.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';

class CompletionDrawer extends StatefulWidget {
  final LocationModel location;
  final CompletionResult? result;
  final VoidCallback? onHide;
  final bool animate;
  final int timeSecs;
  final int moves;

  const CompletionDrawer({
    super.key,
    required this.location,
    this.result,
    this.onHide,
    this.animate = true,
    this.timeSecs = 0,
    this.moves = 0,
  });

  @override
  State<CompletionDrawer> createState() => _CompletionDrawerState();
}

class _CompletionDrawerState extends State<CompletionDrawer> {
  late bool _visible = !widget.animate;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    final loc = widget.location;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    final loc = widget.location;
    final result = widget.result;
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Center(
        child: AnimatedScale(
          scale: _visible ? 1.0 : 0.9,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    // Celebration icon
                    Icon(PhosphorIconsFill.confetti, size: 48, color: AppTheme.trophyGold),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      l10n?.puzzleCompleted ?? 'Puzzle solved!',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22, fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.getLocalizedName(langCode),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tip card (above points)
                    if (loc.getLocalizedTip(langCode).isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.trophyGold.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          loc.getLocalizedTip(langCode),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: Colors.grey.shade800, height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _navigating ? null : widget.onHide,
                        icon: const Icon(PhosphorIconsBold.image, size: 18),
                        label: Text(langCode == 'es' ? 'Ver foto' : 'View photo'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigating ? null : () {
                          setState(() => _navigating = true);
                          AdService.showInterstitial(
                            onAdDismissed: () {
                              if (context.mounted) {
                                Navigator.of(context).pop(result);
                              }
                            },
                          );
                        },
                        icon: const Icon(PhosphorIconsBold.arrowRight, size: 18),
                        label: Text(l10n?.unlockNext ?? 'Continue'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Google Maps link
                    GestureDetector(
                      onTap: _navigating ? null : _openInGoogleMaps,
                      child: Opacity(
                        opacity: _navigating ? 0.4 : 1.0,
                        child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(PhosphorIconsBold.mapPin, size: 18, color: AppTheme.accentBlue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.getLocalizedName(langCode),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    langCode == 'es' ? 'Ver en Google Maps' : 'See on Google Maps',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11, color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(PhosphorIconsBold.arrowRight, size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Points breakdown card
                    if (result != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _PointsRow(
                              icon: PhosphorIconsBold.star,
                              iconColor: AppTheme.trophyGold,
                              label: langCode == 'es' ? 'Puntos base' : 'Base points',
                              value: '+${result.basePoints}',
                            ),
                            if (result.timeBonus > 0) ...[
                              const SizedBox(height: 10),
                              _PointsRow(
                                icon: PhosphorIconsBold.timer,
                                iconColor: AppTheme.accentBlue,
                                label: langCode == 'es' ? 'Bonus de tiempo' : 'Time bonus',
                                value: '+${result.timeBonus}',
                              ),
                            ],
                            if (result.efficiencyBonus > 0) ...[
                              const SizedBox(height: 10),
                              _PointsRow(
                                icon: PhosphorIconsBold.lightning,
                                iconColor: AppTheme.accentOrange,
                                label: langCode == 'es' ? 'Bonus eficiencia' : 'Efficiency bonus',
                                value: '+${result.efficiencyBonus}',
                              ),
                            ],
                            if (result.helpPenalty > 0) ...[
                              const SizedBox(height: 10),
                              _PointsRow(
                                icon: PhosphorIconsBold.shieldWarning,
                                iconColor: Colors.red.shade400,
                                label: langCode == 'es' ? 'Penalización ayuda' : 'Help penalty',
                                value: '-${result.helpPenalty}',
                                valueColor: Colors.red.shade400,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                )),
                                Text(
                                  '${result.totalPoints} pts',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 18, fontWeight: FontWeight.w800,
                                    color: AppTheme.trophyGold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Enter ranking button
                      _RankingButton(
                        totalPoints: GameProgressService.progress.totalPoints,
                        timeSecs: widget.timeSecs,
                        moves: widget.moves,
                        enabled: !_navigating,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Favorite toggle
                    _FavoriteButton(locationId: loc.id, enabled: !_navigating),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final String locationId;
  final bool enabled;
  const _FavoriteButton({required this.locationId, this.enabled = true});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  @override
  Widget build(BuildContext context) {
    final isFav = GameProgressService.isFavorite(widget.locationId);
    final langCode = Localizations.localeOf(context).languageCode;
    return GestureDetector(
      onTap: widget.enabled
          ? () async {
              await GameProgressService.toggleFavorite(widget.locationId);
              setState(() {});
            }
          : null,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isFav ? Colors.redAccent.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFav ? PhosphorIconsFill.heart : PhosphorIconsBold.heart,
              size: 18,
              color: isFav ? Colors.redAccent : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              isFav
                  ? (langCode == 'es' ? 'En favoritos' : 'In favorites')
                  : (langCode == 'es' ? 'Agregar a favoritos' : 'Add to favorites'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isFav ? Colors.redAccent : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RankingButton extends StatefulWidget {
  final int totalPoints;
  final int timeSecs;
  final int moves;
  final bool enabled;
  const _RankingButton({required this.totalPoints, this.timeSecs = 0, this.moves = 0, this.enabled = true});

  @override
  State<_RankingButton> createState() => _RankingButtonState();
}

class _RankingButtonState extends State<_RankingButton> {
  bool _submitting = false;
  int? _rank;

  Future<void> _submitScore() async {
    final langCode = Localizations.localeOf(context).languageCode;
    final currentInitials = GameProgressService.leaderboardInitials;

    final initials = await showInitialsInput(
      context,
      currentInitials: currentInitials,
      totalPoints: widget.totalPoints,
    );
    if (initials == null) return;
    await GameProgressService.setLeaderboardInitials(initials);

    setState(() => _submitting = true);
    final progress = GameProgressService.progress;
    final result = await MockBackend.submitScore(
      initials: initials,
      totalPoints: progress.totalPoints,
      puzzlesCompleted: progress.completedCount,
      timeSeconds: widget.timeSecs,
      moves: widget.moves,
    );
    if (mounted) {
      if (result != null && result.containsKey('error')) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langCode == 'es'
                ? 'No puedes usar esas iniciales'
                : 'Cannot use those initials'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        _submitting = false;
        _rank = result?['rank'];
      });
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(langCode == 'es'
              ? '¡Posición #${result['rank']}!'
              : 'Ranked #${result['rank']}!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final disabled = !widget.enabled;
    final color = disabled ? Colors.grey.shade400 : AppTheme.accentPurple;

    if (_rank != null) {
      return GestureDetector(
        onTap: disabled ? null : () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIconsFill.trophy, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                langCode == 'es' ? '#$_rank — Ver ranking' : '#$_rank — View ranking',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: (_submitting || disabled) ? null : _submitScore,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_submitting)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              Icon(PhosphorIconsBold.listNumbers, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                langCode == 'es' ? 'Entrar al ranking' : 'Enter ranking',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PointsRow extends StatelessWidget {
  final PhosphorIconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _PointsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14, fontWeight: FontWeight.w700, color: valueColor,
          ),
        ),
      ],
    );
  }
}
