import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/puzzle/puzzle_screen.dart';
import 'package:chile_puzzle/features/profile/profile_screen.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:chile_puzzle/features/auth/auth_service.dart';
import 'package:chile_puzzle/core/services/audio_service.dart';
import 'package:chile_puzzle/main.dart';

// Difficulty label helpers
const _diffLabels = {3: 'easy', 4: 'normal', 5: 'hard', 6: 'expert'};
const _diffLabelsEs = {3: 'Facil', 4: 'Normal', 5: 'Dificil', 6: 'Experto'};
const _diffLabelsEn = {3: 'Easy', 4: 'Normal', 5: 'Hard', 6: 'Expert'};
const _diffColors = {
  3: AppTheme.accentGreen,
  4: AppTheme.accentOrange,
  5: AppTheme.accentBlue,
  6: AppTheme.accentPurple,
};

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LocationModel> _locations = [];
  GameConfig _config = GameConfig.fromJson({});
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      if (!await AuthService.isSignedIn()) await AuthService.signIn();
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        MockBackend.fetchLocations(),
        MockBackend.fetchGameConfig(),
      ]);
      if (mounted) {
        setState(() {
          _locations = results[0] as List<LocationModel>;
          _config = results[1] as GameConfig;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  void _toggleLanguage() {
    final currentLocale = Localizations.localeOf(context);
    final newLocale = currentLocale.languageCode == 'es'
        ? const Locale('en')
        : const Locale('es');
    ChilePuzzleApp.setLocale(context, newLocale);
  }

  bool _isLocationUnlocked(LocationModel loc) {
    return GameProgressService.isLocationUnlocked(loc);
  }

  int _getPointsToUnlock(LocationModel loc) {
    return GameProgressService.getPointsToUnlock(loc);
  }

  void _showDifficultyDialog(LocationModel loc) {
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;
    final difficulties = loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels : [3];
    final labels = langCode == 'es' ? _diffLabelsEs : _diffLabelsEn;
    final allDone = difficulties.every(
      (d) => progress.completedPuzzles.containsKey('${loc.id}_$d'),
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.network(
                    loc.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PhosphorIconsBold.x, size: 16, color: Colors.white),
                    ),
                  ),
                ),
                // Title
                Positioned(
                  left: 16, bottom: 12,
                  right: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langCode == 'es' ? 'UBICACION REVELADA' : 'LOCATION REVEALED',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppTheme.trophyGold, letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.getLocalizedName(langCode),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Difficulty grid
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  allDone
                      ? (langCode == 'es' ? 'TODAS COMPLETADAS' : 'ALL COMPLETED')
                      : (langCode == 'es' ? 'ELIGE DIFICULTAD' : 'CHOOSE DIFFICULTY'),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: allDone ? AppTheme.accentGreen : Colors.grey.shade700, letterSpacing: 1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: difficulties.map((diff) {
                  final key = '${loc.id}_$diff';
                  final result = progress.completedPuzzles[key];
                  final isCompleted = result != null;
                  final color = _diffColors[diff] ?? AppTheme.accentBlue;
                  final label = labels[diff] ?? '$diff col';
                  final pts = _config.scoring.basePoints[diff] ?? 50;
                  final icon = _diffIcon(diff);

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _launchPuzzle(loc, diff);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCompleted ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: isCompleted ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5) : null,
                      ),
                      child: Stack(
                        children: [
                          if (isCompleted)
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(PhosphorIconsBold.check, size: 12, color: Colors.white),
                              ),
                            ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 24, color: color),
                                const SizedBox(height: 6),
                                Text(
                                  label,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isCompleted ? '${result.points} pts' : '$diff cols · $pts pts',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11, color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // View photo button (only when all completed)
            if (allDone)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showFullPhoto(loc, langCode);
                  },
                  icon: const Icon(PhosphorIconsBold.image, size: 18),
                  label: Text(langCode == 'es' ? 'Ver foto completa' : 'View full photo'),
                ),
              ),

            // Cancel
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(ctx).padding.bottom.clamp(0, 16)),
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  langCode == 'es' ? 'Cerrar' : 'Close',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PhosphorIconData _diffIcon(int diff) {
    switch (diff) {
      case 3: return PhosphorIconsBold.plant;
      case 4: return PhosphorIconsBold.flame;
      case 5: return PhosphorIconsBold.lightning;
      case 6: return PhosphorIconsBold.skull;
      default: return PhosphorIconsBold.puzzlePiece;
    }
  }

  void _showFullPhoto(LocationModel loc, String langCode) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(loc.image, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey.shade300),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    loc.getLocalizedName(langCode),
                    style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  if (loc.getLocalizedTip(langCode).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      loc.getLocalizedTip(langCode),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(langCode == 'es' ? 'Cerrar' : 'Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPuzzle(LocationModel loc, int difficulty) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PuzzleScreen(
          location: loc,
          difficulty: difficulty,
          gameConfig: _config,
          allLocations: _locations,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;

    return Scaffold(
      appBar: AppBar(
        title: Text('Zoom-In Chile', style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.seedColor,
        )),
        actions: [
          // Points pill
          _AppBarPill(
            icon: PhosphorIconsBold.star,
            iconColor: AppTheme.trophyGold,
            label: '${progress.totalPoints}',
            labelColor: AppTheme.trophyGold,
          ),
          // Trophies pill
          _AppBarPill(
            icon: PhosphorIconsBold.trophy,
            iconColor: AppTheme.accentGreen,
            label: '${progress.earnedTrophyIds.length}',
            labelColor: AppTheme.accentGreen,
          ),
          // Language toggle
          IconButton(
            onPressed: _toggleLanguage,
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsBold.globe, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 2),
                Text(langCode.toUpperCase(), style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500,
                )),
              ],
            ),
          ),
          // Sound toggle
          IconButton(
            onPressed: () => setState(() => AudioService.toggleMute()),
            icon: Icon(
              AudioService.isMuted ? PhosphorIconsBold.speakerSlash : PhosphorIconsBold.speakerHigh,
              size: 20, color: Colors.grey.shade600,
            ),
            visualDensity: VisualDensity.compact,
          ),
          // Profile
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(config: _config, allLocations: _locations)),
            ).then((_) { if (mounted) setState(() {}); }),
            icon: Icon(PhosphorIconsBold.userCircle, size: 24, color: Colors.grey.shade600),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(langCode, progress, l10n),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsBold.cloudSlash, size: 56, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text('Could not load locations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _loadData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String langCode, dynamic progress, AppLocalizations l10n) {
    // Sort: new unlocks first, then in-progress, then completed, then locked
    final sorted = List<LocationModel>.from(_locations);
    sorted.sort((a, b) {
      final aUnlocked = _isLocationUnlocked(a);
      final bUnlocked = _isLocationUnlocked(b);
      final aDiffs = a.difficultyLevels.isNotEmpty ? a.difficultyLevels : [3];
      final bDiffs = b.difficultyLevels.isNotEmpty ? b.difficultyLevels : [3];
      final aDone = aDiffs.where((d) => progress.completedPuzzles.containsKey('${a.id}_$d')).length;
      final bDone = bDiffs.where((d) => progress.completedPuzzles.containsKey('${b.id}_$d')).length;

      int bucket(bool unlocked, int done, int total) {
        if (!unlocked) return 3; // locked
        if (done == 0) return 0; // new unlock
        if (done < total) return 1; // in progress
        return 2; // all completed
      }

      final aBucket = bucket(aUnlocked, aDone, aDiffs.length);
      final bBucket = bucket(bUnlocked, bDone, bDiffs.length);
      if (aBucket != bBucket) return aBucket.compareTo(bBucket);
      return 0; // preserve original order within same bucket
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            return _buildLocationCard(sorted[index], langCode, progress);
          },
        ),
      ],
    );
  }

  Widget _buildLocationCard(LocationModel loc, String langCode, dynamic progress) {
    final difficulties = loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels : [3];
    final completedDiffs = difficulties.where(
      (d) => progress.completedPuzzles.containsKey('${loc.id}_$d'),
    ).toList();
    final allCompleted = completedDiffs.length == difficulties.length;
    final isUnlocked = _isLocationUnlocked(loc);

    // B&W progressive: 1.0 = full color, 0.0 = full grayscale
    final double saturation = allCompleted
        ? 1.0
        : completedDiffs.isEmpty
            ? 0.0
            : 0.4 + 0.6 * (completedDiffs.length / difficulties.length);

    return GestureDetector(
      onTap: () {
        if (!isUnlocked) {
          final pts = _getPointsToUnlock(loc);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(langCode == 'es'
                  ? '$pts puntos mas para desbloquear'
                  : '$pts more points to unlock'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _showDifficultyDialog(loc);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image with B&W / blur filter
            _LocationImage(
              imageUrl: loc.image,
              isUnlocked: isUnlocked,
              saturation: saturation,
            ),
            // Gradient at bottom for text + icons
            Positioned(
              left: 0, right: 0, bottom: 0, height: 70,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),
            // Lock overlay for locked
            if (!isUnlocked)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsBold.lock, size: 22, color: Colors.white70),
                        const SizedBox(height: 4),
                        Text(
                          '${_getPointsToUnlock(loc)} pts',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Name
            Positioned(
              left: 10, bottom: 30, right: 10,
              child: Text(
                loc.getLocalizedName(langCode),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            // Difficulty icons over photo
            Positioned(
              left: 10, bottom: 6,
              child: Row(
                children: difficulties.map((d) {
                  final done = completedDiffs.contains(d);
                  final color = _diffColors[d] ?? AppTheme.accentBlue;
                  final icon = _diffIcon(d);

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: done ? color : Colors.white24,
                        shape: BoxShape.circle,
                        border: done ? null : Border.all(
                          color: Colors.white38,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        icon, size: 13,
                        color: done ? Colors.white : Colors.white60,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Applies grayscale or blur filter to location image
class _LocationImage extends StatelessWidget {
  final String imageUrl;
  final bool isUnlocked;
  final double saturation; // 0.0 = B&W, 1.0 = full color

  const _LocationImage({
    required this.imageUrl,
    required this.isUnlocked,
    required this.saturation,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: Icon(PhosphorIconsBold.image, size: 32, color: Colors.grey.shade600),
      ),
    );

    if (!isUnlocked) {
      // Locked: blur + grayscale
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: image,
        ),
      );
    }

    if (saturation >= 1.0) return image;

    // Progressive B&W: interpolate between grayscale and color
    final s = saturation;
    final r = 0.2126, g = 0.7152, b = 0.0722;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        r + (1 - r) * s,  g * (1 - s),      b * (1 - s),      0, 0,
        r * (1 - s),      g + (1 - g) * s,  b * (1 - s),      0, 0,
        r * (1 - s),      g * (1 - s),      b + (1 - b) * s,  0, 0,
        0,                0,                0,                 1, 0,
      ]),
      child: image,
    );
  }
}

class _AppBarPill extends StatelessWidget {
  final PhosphorIconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  const _AppBarPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13, fontWeight: FontWeight.w700, color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
