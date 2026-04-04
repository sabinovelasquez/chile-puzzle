import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/ads/ad_service.dart';
import 'package:chile_puzzle/features/puzzle/icon_mapping.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';

class CompletionDrawer extends StatefulWidget {
  final LocationModel location;
  final CompletionResult? result;

  const CompletionDrawer({
    super.key,
    required this.location,
    this.result,
  });

  @override
  State<CompletionDrawer> createState() => _CompletionDrawerState();
}

class _CompletionDrawerState extends State<CompletionDrawer> {
  bool _drawerOpen = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _drawerOpen = true);
    });
  }

  void _openFullMap(LatLng latLng, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(fontSize: 14)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: GoogleMap(
            initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
            markers: {Marker(markerId: const MarkerId('loc'), position: latLng)},
            myLocationButtonEnabled: false,
            mapToolbarEnabled: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    final loc = widget.location;
    final result = widget.result;
    final latLng = LatLng(loc.latitude, loc.longitude);
    final screenHeight = MediaQuery.of(context).size.height;
    final drawerHeight = screenHeight * 0.55;

    return Stack(
      children: [
        // Tap anywhere to reopen
        if (!_drawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _drawerOpen = true),
              behavior: HitTestBehavior.translucent,
            ),
          ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: _drawerOpen ? 0 : -drawerHeight,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              setState(() {
                _drawerOpen = details.velocity.pixelsPerSecond.dy <= 0;
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xF0FFFFFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
              ),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle — tap to toggle
                    GestureDetector(
                      onTap: () => setState(() => _drawerOpen = !_drawerOpen),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    // Points
                    if (result != null) ...[
                      Text(
                        '+${result.totalPoints}',
                        style: TextStyle(
                          color: AppTheme.trophyGold,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          '${result.basePoints} base',
                          if (result.timeBonus > 0) '+${result.timeBonus} time',
                          if (result.efficiencyBonus > 0) '+${result.efficiencyBonus} efficiency',
                        ].join('  ·  '),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],

                    // New trophies
                    if (result != null && result.newTrophies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: result.newTrophies.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.trophyGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(mapIcon(t.icon), size: 18, color: AppTheme.trophyGold),
                                const SizedBox(width: 6),
                                Text(
                                  t.getLocalizedName(langCode),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Location name + region
                    Text(
                      loc.getLocalizedName(langCode),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A4B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.region,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Map — larger
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => _openFullMap(latLng, loc.getLocalizedName(langCode)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 160,
                            child: IgnorePointer(
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(target: latLng, zoom: 14),
                                markers: {Marker(markerId: const MarkerId('loc'), position: latLng)},
                                zoomControlsEnabled: false,
                                scrollGesturesEnabled: false,
                                rotateGesturesEnabled: false,
                                tiltGesturesEnabled: false,
                                zoomGesturesEnabled: false,
                                myLocationButtonEnabled: false,
                                mapToolbarEnabled: false,
                                liteModeEnabled: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tip
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        loc.getLocalizedTip(langCode),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () {
                                final pts = result?.totalPoints ?? 0;
                                Share.share('${loc.getLocalizedName(langCode)} — $pts pts! #ChilePuzzleExplorer');
                              },
                              icon: Icon(Icons.share_outlined, color: Colors.grey.shade600, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  AdService.showInterstitial(
                                    onAdDismissed: () {
                                      if (context.mounted) {
                                        Navigator.of(context).pop(result);
                                      }
                                    },
                                  );
                                },
                                child: Text(l10n?.unlockNext ?? 'Continue'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
