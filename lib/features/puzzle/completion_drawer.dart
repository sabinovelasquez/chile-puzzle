import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/ads/ad_service.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';

class CompletionDrawer extends StatefulWidget {
  final LocationModel location;
  final CompletionResult? result;
  final VoidCallback? onHide;

  const CompletionDrawer({
    super.key,
    required this.location,
    this.result,
    this.onHide,
  });

  @override
  State<CompletionDrawer> createState() => _CompletionDrawerState();
}

class _CompletionDrawerState extends State<CompletionDrawer> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _visible = true);
    });
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
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
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 4),

                    // Google Maps link
                    GestureDetector(
                      onTap: _openInGoogleMaps,
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
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onHide,
                            icon: const Icon(PhosphorIconsBold.image, size: 18),
                            label: Text(langCode == 'es' ? 'Ver foto' : 'View photo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

  const _PointsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
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
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
