import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/services/settings_service.dart';
import 'package:chile_puzzle/core/services/loading_overlay_service.dart';
import 'package:chile_puzzle/core/widgets/app_loader.dart';
import 'package:chile_puzzle/core/services/share_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/puzzle/puzzle_screen.dart';
import 'package:chile_puzzle/features/profile/profile_screen.dart';
import 'package:chile_puzzle/features/leaderboard/leaderboard_screen.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:chile_puzzle/features/auth/auth_service.dart';
import 'package:chile_puzzle/main.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Difficulty label helpers
const _diffLabelsEs = {3: 'Facil', 4: 'Normal', 5: 'Dificil', 6: 'Experto'};
const _diffLabelsEn = {3: 'Easy', 4: 'Normal', 5: 'Hard', 6: 'Expert'};
const _diffColors = {
  3: AppTheme.accentGreen,
  4: AppTheme.accentOrange,
  5: AppTheme.accentBlue,
  6: AppTheme.accentPurple,
};

const _diffLabelPillEs = {
  3: 'Fácil completado',
  4: 'Normal completado',
  5: 'Difícil completado',
  6: 'Experto completado',
};
const _diffLabelPillEn = {
  3: 'Easy completed',
  4: 'Normal completed',
  5: 'Hard completed',
  6: 'Expert completed',
};

/// Small rounded "{Level} completed" pill used above the tip text on the
/// full-photo carousel and the puzzle_screen post-completion overlay.
/// Color-coded by difficulty to match the rest of the app.
Widget _buildLevelPill({required int difficulty, required String langCode}) {
  final color = _diffColors[difficulty] ?? AppTheme.accentBlue;
  final label =
      (langCode == 'es' ? _diffLabelPillEs : _diffLabelPillEn)[difficulty] ??
          '';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: color.withValues(alpha: 0.40),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsFill.checkCircle, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  List<LocationModel> _locations = [];
  List<LocationModel> _allLocations = [];
  GameConfig _config = GameConfig.fromJson({});
  bool _isLoading = true;
  String? _error;

  // Filters
  String _activeFilter = 'all'; // 'all','new','in_progress','completed','favorites'
  String? _activeZone;
  String _searchQuery = '';
  bool _searchExpanded = false;
  Timer? _searchDebounce;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  // Onboarding pulse — drives the fade-in-out of the play icon on unlocked
  // cards for brand-new players (before their first puzzle completion).
  late final AnimationController _onboardingPulse;

  @override
  void initState() {
    super.initState();
    _onboardingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initData();
    _initAuth();
  }

  @override
  void dispose() {
    _onboardingPulse.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAuth() async {
    try {
      if (!await AuthService.isSignedIn()) await AuthService.signIn();
    } catch (_) {}
  }

  Future<void> _initData() async {
    try {
      final results = await Future.wait([
        MockBackend.fetchGameConfig(),
        MockBackend.fetchLocations(),
      ]);
      if (!mounted) return;
      setState(() {
        _config = results[0] as GameConfig;
        _allLocations = results[1] as List<LocationModel>;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  /// Computes `_locations` from `_allLocations` + the active filter, zone, and
  /// search query. All client-side — sorting for the 'all' view happens later
  /// in `_sortByStatus` so it stays in sync with player progress on rebuild.
  void _applyFilters() {
    final progress = GameProgressService.progress;
    Iterable<LocationModel> result = _allLocations;

    if (_activeZone != null && _activeZone!.isNotEmpty) {
      result = result.where((l) => l.region == _activeZone);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((l) =>
          l.getLocalizedName('es').toLowerCase().contains(q) ||
          l.getLocalizedName('en').toLowerCase().contains(q));
    }

    switch (_activeFilter) {
      case 'in_progress':
        final ids = _getInProgressIds(progress).toSet();
        result = result.where((l) => ids.contains(l.id));
        break;
      case 'completed':
        final ids = _getCompletedIds(progress).toSet();
        result = result.where((l) => ids.contains(l.id));
        break;
      case 'favorites':
        final ids = GameProgressService.favoriteLocationIds.toSet();
        result = result.where((l) => ids.contains(l.id));
        break;
      case 'new':
        final sorted = result.toList()..sort(_byCreatedAtDesc);
        result = sorted.take(25);
        break;
      // 'all': no extra filtering; `_sortByStatus` handles bucket ordering.
    }

    if (mounted) {
      setState(() {
        _locations = result.toList();
      });
    }
  }

  static int _byCreatedAtDesc(LocationModel a, LocationModel b) {
    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final cmp = bDate.compareTo(aDate);
    if (cmp != 0) return cmp;
    return a.id.compareTo(b.id);
  }

  int _getDifficultyCount(String locId) {
    final loc = _allLocations.where((l) => l.id == locId).firstOrNull;
    return loc != null && loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels.length : 4;
  }

  List<String> _getInProgressIds(dynamic progress) {
    // Locations with some but not all difficulties completed
    final Map<String, int> completedByLoc = {};
    for (final key in progress.completedPuzzles.keys) {
      final k = key.toString();
      final locId = k.substring(0, k.lastIndexOf('_'));
      completedByLoc[locId] = (completedByLoc[locId] ?? 0) + 1;
    }
    return completedByLoc.entries
        .where((e) => e.value > 0 && e.value < _getDifficultyCount(e.key))
        .map((e) => e.key)
        .toList();
  }

  List<String> _getCompletedIds(dynamic progress) {
    final Map<String, int> completedByLoc = {};
    for (final key in progress.completedPuzzles.keys) {
      final k = key.toString();
      final locId = k.substring(0, k.lastIndexOf('_'));
      completedByLoc[locId] = (completedByLoc[locId] ?? 0) + 1;
    }
    return completedByLoc.entries
        .where((e) => e.value >= _getDifficultyCount(e.key))
        .map((e) => e.key)
        .toList();
  }

  void _onFilterChanged(String filter) {
    if (filter == _activeFilter && _activeZone == null && _searchQuery.isEmpty) return;
    _activeFilter = filter;
    _activeZone = null;
    _searchQuery = '';
    _searchController.clear();
    _applyFilters();
  }

  void _onZoneChanged(String? zone) {
    _activeZone = zone;
    _activeFilter = 'all';
    _searchQuery = '';
    _searchController.clear();
    _applyFilters();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.isNotEmpty && value.length < 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = value;
      _activeFilter = 'all';
      _activeZone = null;
      _applyFilters();
    });
  }

  void _toggleLanguage() {
    final currentLocale = Localizations.localeOf(context);
    final newLocale = currentLocale.languageCode == 'es'
        ? const Locale('en')
        : const Locale('es');
    ChilePuzzleApp.setLocale(context, newLocale);
  }

  String _compactNumber(int n) {
    if (n < 10000) return '$n';
    if (n < 1000000) {
      final k = n / 1000;
      return k == k.truncateToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    final m = n / 1000000;
    return m == m.truncateToDouble() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
  }

  bool _isLocationUnlocked(LocationModel loc) {
    return GameProgressService.isLocationUnlocked(loc);
  }

  Future<void> _openInGoogleMaps(LocationModel loc) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showLocationInfoDialog(LocationModel loc) {
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;
    final difficulties = loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels : [3];
    final completedDiffs = difficulties.where(
      (d) => progress.completedPuzzles.containsKey('${loc.id}_$d'),
    ).toList();
    if (completedDiffs.isEmpty) return;
    final allCompleted = completedDiffs.length == difficulties.length;
    final labels = langCode == 'es' ? _diffLabelsEs : _diffLabelsEn;

    // Build deduplicated tip slides, preserving order by difficulty.
    final seen = <String>{};
    final slides = <_TipSlide>[];
    for (final d in completedDiffs) {
      final text = loc.getLocalizedTipForDifficulty(langCode, d);
      if (text.isEmpty) continue;
      if (seen.add(text)) {
        slides.add(_TipSlide(difficulty: d, label: labels[d] ?? '', text: text));
      }
    }
    if (slides.isEmpty) return;

    // Silhouette header badge earned by beating Expert OR by clearing every
    // difficulty the location offers.
    final expertDone = progress.completedPuzzles.containsKey('${loc.id}_6');
    final locDiffsTip = loc.difficultyLevels.isNotEmpty
        ? loc.difficultyLevels
        : const [3];
    final allLocDiffsDone = locDiffsTip.every(
      (d) => progress.completedPuzzles.containsKey('${loc.id}_$d'),
    );
    final tipHeaderIsSilhouette = expertDone || allLocDiffsDone;

    final controller = PageController();
    final pageNotifier = ValueNotifier<int>(0);

    showDialog(
      context: context,
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    tipHeaderIsSilhouette
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: SvgPicture.asset(
                              'assets/girl_cat.svg',
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Icon(PhosphorIconsBold.lightbulb,
                            size: 20, color: AppTheme.trophyGold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.getLocalizedName(langCode),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade900,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(PhosphorIconsBold.x, size: 14, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              // Tip body — single tip or carousel
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: [
                    SizedBox(
                      height: 220,
                      child: slides.length == 1
                          ? _buildTipCard(slides.first, allCompleted: allCompleted)
                          : PageView.builder(
                              controller: controller,
                              itemCount: slides.length,
                              onPageChanged: (i) => pageNotifier.value = i,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: _buildTipCard(slides[i], allCompleted: allCompleted),
                              ),
                            ),
                    ),
                    // Silhouette only on the Expert slide (difficulty 6)
                    ValueListenableBuilder<int>(
                      valueListenable: pageNotifier,
                      builder: (_, current, __) {
                        if (current >= slides.length) return const SizedBox.shrink();
                        final showOn = slides[current].difficulty == 6;
                        if (!showOn) return const SizedBox.shrink();
                        return Positioned(
                          right: 6,
                          bottom: -10,
                          child: IgnorePointer(
                            child: SizedBox(
                              width: 110,
                              height: 89,
                              child: SvgPicture.asset(
                                'assets/girl_cat.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Dot indicators (only for carousel)
              if (slides.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ValueListenableBuilder<int>(
                    valueListenable: pageNotifier,
                    builder: (_, current, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(slides.length, (i) {
                        final active = i == current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? AppTheme.trophyGold : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                )
              else
                const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    ).then((_) {
      controller.dispose();
      pageNotifier.dispose();
    });
  }

  Widget _buildTipCard(_TipSlide slide, {required bool allCompleted}) {
    final color = _diffColors[slide.difficulty] ?? AppTheme.accentBlue;
    // Extra bottom padding only on the Expert slide to make room for the girl_cat silhouette
    final bottomPad = (allCompleted && slide.difficulty == 6) ? 85.0 : 14.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 14, 14, bottomPad),
      decoration: BoxDecoration(
        color: AppTheme.trophyGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              slide.label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                slide.text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: Colors.grey.shade800, height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDifficultyDialog(LocationModel loc) {
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;
    final difficulties = loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels : [3];
    final labels = langCode == 'es' ? _diffLabelsEs : _diffLabelsEn;
    final anyCompleted = difficulties.any(
      (d) => progress.completedPuzzles.containsKey('${loc.id}_$d'),
    );
    // Highest completed difficulty — used when opening the photo overlay from
    // the "Ver foto" button so the tip shown matches the hardest run.
    final topDiff = difficulties.reduce((a, b) => a > b ? a : b);

    // Per-session hint toggles — on the very first run (no puzzles completed
    // yet), start everything off so a new player doesn't get blindsided with
    // pre-toggled penalties. After that, remember the last choice.
    final isFirstRun = progress.completedPuzzles.isEmpty;
    bool hintLock = isFirstRun ? false : SettingsService.lastHintLock;
    bool hintMulti = isFirstRun ? false : SettingsService.lastHintMulti;
    bool hintReference = isFirstRun ? false : SettingsService.lastHintReference;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling),
        child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(
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
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: AppLoader(size: 32)),
                      );
                    },
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

            // Optional per-session hints + running penalty, all in one
            // centered row so the cost reads like a direct consequence of
            // the active toggles. Each toggle fires a trophy-style top
            // notification with a short explanation (no penalty text — the
            // pill reports the total).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.creamBackground, width: 1.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _hintIconToggle(
                          icon: PhosphorIconsBold.lock,
                          iconFill: PhosphorIconsFill.lock,
                          selected: hintLock,
                          onTap: () {
                            setDialogState(() => hintLock = !hintLock);
                            _showHintNotification(
                              ctx: ctx, langCode: langCode,
                              hint: _HintKind.lock, enabled: hintLock,
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _hintIconToggle(
                          icon: PhosphorIconsBold.squaresFour,
                          iconFill: PhosphorIconsFill.squaresFour,
                          selected: hintMulti,
                          onTap: () {
                            setDialogState(() => hintMulti = !hintMulti);
                            _showHintNotification(
                              ctx: ctx, langCode: langCode,
                              hint: _HintKind.multi, enabled: hintMulti,
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _hintIconToggle(
                          icon: PhosphorIconsBold.image,
                          iconFill: PhosphorIconsFill.image,
                          selected: hintReference,
                          onTap: () {
                            setDialogState(() => hintReference = !hintReference);
                            _showHintNotification(
                              ctx: ctx, langCode: langCode,
                              hint: _HintKind.reference, enabled: hintReference,
                            );
                          },
                        ),
                      ],
                    ),
                    if (_hintTotalPenalty(hintLock, hintMulti, hintReference) > 0)
                      _HintPenaltyBadge(
                        penalty: _hintTotalPenalty(hintLock, hintMulti, hintReference),
                        langCode: langCode,
                      )
                    else
                      Text(
                        langCode == 'es' ? 'Potenciadores' : 'Power-ups',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.2,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Subtle separator between hints row and the level list.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
            ),
            // Difficulty grid — each tile stacks: icon · name · points.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: difficulties.map((diff) {
                  final key = '${loc.id}_$diff';
                  final isCompleted = progress.completedPuzzles.containsKey(key);
                  final color = _diffColors[diff] ?? AppTheme.accentBlue;
                  final label = labels[diff] ?? '$diff col';
                  final pts = _config.scoring.basePoints[diff] ?? 50;
                  final icon = _diffIcon(diff);

                  final bg = isCompleted ? color : color.withValues(alpha: 0.12);
                  final fg = isCompleted ? Colors.white : color;
                  final subFg = isCompleted
                      ? Colors.white.withValues(alpha: 0.9)
                      : color.withValues(alpha: 0.85);

                  return GestureDetector(
                    onTap: () async {
                      await SettingsService.setLastHints(
                        lock: hintLock,
                        multi: hintMulti,
                        reference: hintReference,
                      );
                      if (!mounted) return;
                      // Keep the dialog open while we ensure the image is
                      // available. _launchPuzzle pops the dialog itself
                      // (only on success) right before pushing the puzzle —
                      // matches the smooth flow used by "Ver completados".
                      _launchPuzzle(
                        loc,
                        diff,
                        dialogContext: ctx,
                        lockInPlace: hintLock,
                        multiSelect: hintMulti,
                        referenceEnabled: hintReference,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 22, color: fg),
                                const SizedBox(height: 6),
                                Text(
                                  label,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$pts pts',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCompleted)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  PhosphorIconsBold.check,
                                  size: 13,
                                  color: color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),

            // Ver completados — available as soon as at least one level is done.
            if (anyCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showFullPhoto(loc, langCode, topDiff);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7396A4),
                      side: const BorderSide(color: Color(0xFFB8CDD4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(PhosphorIconsBold.image, size: 15),
                    label: Text(langCode == 'es' ? 'Ver completados' : 'View completed'),
                  ),
                ),
              ),

            // Ver en Google Maps — same unlock rule as Ver foto.
            if (anyCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openInGoogleMaps(loc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7396A4),
                      side: const BorderSide(color: Color(0xFFB8CDD4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(PhosphorIconsBold.mapPin, size: 15),
                    label: Text(langCode == 'es' ? 'Ver en Google Maps' : 'See on Google Maps'),
                  ),
                ),
              ),

            // Ver ranking — opens the per-location leaderboard for the
            // highest difficulty the player has completed here (Normal as
            // fallback if none).
            if (anyCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final pickDiff = [6, 5, 4, 3].firstWhere(
                        (d) => GameProgressService.getBestPoints(loc.id, d) != null,
                        orElse: () => 4,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeaderboardScreen(
                            locationId: loc.id,
                            difficulty: pickDiff,
                            locationName: loc.getLocalizedName(langCode),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7396A4),
                      side: const BorderSide(color: Color(0xFFB8CDD4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    icon: const Icon(PhosphorIconsBold.ranking, size: 15),
                    label: Text(langCode == 'es' ? 'Ver ranking' : 'View ranking'),
                  ),
                ),
              ),

            // Cancel
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(ctx).padding.bottom.clamp(0, 16)),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7396A4),
                    side: const BorderSide(color: Color(0xFFB8CDD4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  child: Text(langCode == 'es' ? 'Cerrar' : 'Close'),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _hintIconToggle({
    required IconData icon,
    required IconData iconFill,
    required bool selected,
    required VoidCallback onTap,
  }) {
    // Off = outlined icon on light grey. On = white bg + dark grey fill icon
    // + small green check badge at the top-right so the active state is
    // impossible to miss.
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              selected ? iconFill : icon,
              size: 20,
              color: selected ? Colors.grey.shade700 : Colors.grey.shade500,
            ),
          ),
          if (selected)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  PhosphorIconsBold.check,
                  size: 9,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Trophy-style top notification for a hint toggle. Bilingual, no penalty
  /// text (the running pill handles that). Inserting into the root overlay
  /// means the notification sits above the difficulty modal and is cleanly
  /// replaced when the player taps another toggle in rapid succession.
  void _showHintNotification({
    required BuildContext ctx,
    required String langCode,
    required _HintKind hint,
    required bool enabled,
  }) {
    final es = langCode == 'es';
    late final PhosphorIconData icon;
    late final String text;
    switch (hint) {
      case _HintKind.lock:
        icon = PhosphorIconsBold.lock;
        text = enabled
            ? (es
                ? 'Piezas correctas quedan fijas.'
                : 'Correct pieces stay locked.')
            : (es ? 'Fijar piezas: desactivado.' : 'Lock pieces: off.');
        break;
      case _HintKind.multi:
        icon = PhosphorIconsBold.squaresFour;
        text = enabled
            ? (es
                ? 'Arrastras grupos de piezas juntas.'
                : 'Drag groups of pieces together.')
            : (es ? 'Mover grupos: desactivado.' : 'Move groups: off.');
        break;
      case _HintKind.reference:
        icon = PhosphorIconsBold.image;
        text = enabled
            ? (es
                ? 'Ves la foto original durante el juego (3 vistas).'
                : 'See the original photo during play (3 peeks).')
            : (es ? 'Foto de referencia: desactivado.' : 'Reference photo: off.');
        break;
    }
    _HintNotificationHost.show(ctx, icon: icon, text: text);
  }

  /// Sum of penalties for the currently-enabled hints. 0 when nothing selected.
  /// Reference (-25) is the costliest because seeing the finished photo during
  /// play is the biggest advantage of the three.
  int _hintTotalPenalty(bool lock, bool multi, bool reference) {
    return (lock ? 15 : 0) + (multi ? 20 : 0) + (reference ? 25 : 0);
  }

  PhosphorIconData _zoneIcon(String iconName) {
    switch (iconName) {
      case 'trophy': return PhosphorIconsBold.trophy;
      case 'star': return PhosphorIconsBold.star;
      case 'bolt': case 'lightning': return PhosphorIconsBold.lightning;
      case 'timer': return PhosphorIconsBold.timer;
      case 'diamond': return PhosphorIconsBold.diamond;
      case 'flag': return PhosphorIconsBold.flag;
      case 'puzzle_piece': return PhosphorIconsBold.puzzlePiece;
      case 'mountains': case 'landscape': return PhosphorIconsBold.mountains;
      case 'compass': return PhosphorIconsBold.compass;
      case 'medal': return PhosphorIconsBold.medal;
      case 'crown': return PhosphorIconsBold.crown;
      case 'fire': case 'flame': return PhosphorIconsBold.flame;
      case 'rocket': return PhosphorIconsBold.rocket;
      case 'eye': return PhosphorIconsBold.eye;
      case 'globe': return PhosphorIconsBold.globe;
      case 'map_pin': return PhosphorIconsBold.mapPin;
      case 'camera': return PhosphorIconsBold.camera;
      case 'heart': return PhosphorIconsBold.heart;
      case 'shield': return PhosphorIconsBold.shield;
      case 'target': return PhosphorIconsBold.target;
      case 'binoculars': return PhosphorIconsBold.binoculars;
      case 'path': return PhosphorIconsBold.path;
      case 'sun': return PhosphorIconsBold.sun;
      case 'map_trifold': return PhosphorIconsBold.mapTrifold;
      case 'plant': return PhosphorIconsBold.plant;
      case 'skull': return PhosphorIconsBold.skull;
      case 'spiral': return PhosphorIconsBold.spiral;
      default: return PhosphorIconsBold.mapPin;
    }
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

  void _showFullPhoto(LocationModel loc, String langCode, int difficulty) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 100),
        transitionsBuilder: (ctx, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (ctx, _, __) => _FullPhotoView(
          location: loc,
          difficulty: difficulty,
          langCode: langCode,
        ),
      ),
    );
  }

  Future<void> _launchPuzzle(
    LocationModel loc,
    int difficulty, {
    BuildContext? dialogContext,
    bool lockInPlace = false,
    bool multiSelect = false,
    bool referenceEnabled = false,
  }) async {
    final imageUrl = loc.getImageForDifficulty(difficulty);
    final imageProvider = CachedNetworkImageProvider(imageUrl);

    // Show the global loader IMMEDIATELY so the tap registers visually —
    // the dialog stays open underneath, but the loader sits above it so
    // the user never wonders if their tap was received.
    //
    // We pre-resolve the image into Flutter's in-memory cache (not just
    // the on-disk cache) so that when the puzzle screen mounts, its own
    // CachedNetworkImage hits the cache instantly and never flashes a
    // second loader on top of the first one.
    LoadingOverlayService.show();
    try {
      await precacheImage(imageProvider, context)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      LoadingOverlayService.hide();
      if (!mounted) return;
      final langCode = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'es'
              ? 'Necesitas conexión para descargar este puzzle'
              : 'You need a connection to download this puzzle'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    LoadingOverlayService.hide();
    if (!mounted) return;
    // Pop the difficulty dialog (if any) and push the puzzle in the
    // same frame — the dialog's exit animation overlaps the puzzle
    // route's fade-in, so the user never sees the bare map between
    // the two screens.
    if (dialogContext != null && Navigator.canPop(dialogContext)) {
      Navigator.pop(dialogContext);
    }
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (ctx, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (ctx, _, __) => PuzzleScreen(
          location: loc,
          difficulty: difficulty,
          gameConfig: _config,
          allLocations: _allLocations,
          lockInPlace: lockInPlace,
          multiSelect: multiSelect,
          referenceEnabled: referenceEnabled,
        ),
      ),
    );
    if (mounted) {
      // Refresh to pick up new progress, favorites, and any admin-side edits.
      try {
        final fresh = await MockBackend.fetchLocations();
        if (mounted) _allLocations = fresh;
      } catch (_) {}
      if (mounted) _applyFilters();
    }
    // Hide the global loader if the puzzle flow raised it (after ad dismiss).
    // Safe to call unconditionally — hide() is a no-op when already hidden.
    LoadingOverlayService.hide();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/zoom-in-chile-title.png', height: 36),
        actions: [
          // Points pill
          _AppBarPill(
            icon: PhosphorIconsBold.star,
            iconColor: AppTheme.trophyGold,
            label: _compactNumber(progress.totalPoints),
            labelColor: AppTheme.trophyGold,
          ),
          // Settings
          IconButton(
            onPressed: () => showSettingsDialog(context),
            icon: Icon(
              PhosphorIconsBold.gear,
              size: 20, color: Colors.grey.shade600,
            ),
            visualDensity: VisualDensity.compact,
          ),
          // Search toggle
          IconButton(
            onPressed: () => setState(() => _searchExpanded = !_searchExpanded),
            icon: Icon(PhosphorIconsBold.magnifyingGlass, size: 20, color: Colors.grey.shade600),
            visualDensity: VisualDensity.compact,
          ),
          // Profile
          IconButton(
            onPressed: () {
              setState(() => _searchExpanded = false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(config: _config, allLocations: _allLocations)),
              ).then((_) { if (mounted) setState(() {}); });
            },
            icon: Icon(PhosphorIconsBold.userCircle, size: 24, color: Colors.grey.shade600),
          ),
        ],
      ),
      body: _error != null
              ? _buildError()
              : _buildBody(langCode, progress, l10n),
    );
  }

  Widget _buildOfflineBanner(String langCode) {
    final ageLabel = _relativeAge(MockBackend.lastSyncedAt, langCode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.accentOrange.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(PhosphorIconsBold.cloudSlash, size: 18, color: AppTheme.accentOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              langCode == 'es'
                  ? (ageLabel == null
                      ? 'Sin conexión — mostrando lo que tienes guardado'
                      : 'Sin conexión — última sincronización $ageLabel')
                  : (ageLabel == null
                      ? "Offline — showing what's saved"
                      : 'Offline — last synced $ageLabel'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentOrange,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _initData();
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              langCode == 'es' ? 'Reintentar' : 'Retry',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String langCode, {required bool isOffline}) {
    // Two cases:
    //   - offline + the raw location list is empty (fetch failed, no cache) → offline message + retry
    //   - any other empty (filter, search, zone with no matches) → "Sin resultados"
    final isOfflineEmpty = isOffline && _allLocations.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOfflineEmpty
                  ? PhosphorIconsBold.cloudSlash
                  : PhosphorIconsBold.magnifyingGlass,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isOfflineEmpty
                  ? (langCode == 'es'
                      ? 'Sin conexión'
                      : 'No connection')
                  : (langCode == 'es' ? 'Sin resultados' : 'No results'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            if (isOfflineEmpty) ...[
              const SizedBox(height: 6),
              Text(
                langCode == 'es'
                    ? 'Revisa tu conexión y vuelve a intentar'
                    : 'Check your connection and try again',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _isLoading = true; _error = null; });
                  _initData();
                },
                icon: const Icon(PhosphorIconsBold.arrowClockwise, size: 18),
                label: Text(langCode == 'es' ? 'Reintentar' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "hace 3 min" / "3 min ago" — compact humanized age for the offline banner.
  String? _relativeAge(DateTime? when, String langCode) {
    if (when == null) return null;
    final diff = DateTime.now().difference(when);
    final es = langCode == 'es';
    if (diff.inMinutes < 1) return es ? 'hace instantes' : 'just now';
    if (diff.inMinutes < 60) {
      return es ? 'hace ${diff.inMinutes} min' : '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return es ? 'hace ${diff.inHours} h' : '${diff.inHours} h ago';
    }
    return es ? 'hace ${diff.inDays} d' : '${diff.inDays} d ago';
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
              _initData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<LocationModel> _sortByStatus(List<LocationModel> locs, dynamic progress) {
    final sorted = List<LocationModel>.from(locs);
    sorted.sort((a, b) {
      final aUnlocked = _isLocationUnlocked(a);
      final bUnlocked = _isLocationUnlocked(b);
      final aDiffs = a.difficultyLevels.isNotEmpty ? a.difficultyLevels : [3];
      final bDiffs = b.difficultyLevels.isNotEmpty ? b.difficultyLevels : [3];
      final aDone = aDiffs.where((d) => progress.completedPuzzles.containsKey('${a.id}_$d')).length;
      final bDone = bDiffs.where((d) => progress.completedPuzzles.containsKey('${b.id}_$d')).length;

      int bucket(bool unlocked, int done, int total) {
        if (!unlocked) return 3;
        if (done == 0) return 0;
        if (done < total) return 1;
        return 2;
      }

      final aBucket = bucket(aUnlocked, aDone, aDiffs.length);
      final bBucket = bucket(bUnlocked, bDone, bDiffs.length);
      if (aBucket != bBucket) return aBucket.compareTo(bBucket);
      // Within in-progress bucket, sort least completed first.
      if (aBucket == 1) {
        final progCmp = aDone.compareTo(bDone);
        if (progCmp != 0) return progCmp;
      }
      // Within the same bucket, newest first (freshly uploaded locations
      // surface at the top of "new unlocks"). `id` is the stable tiebreaker.
      return _byCreatedAtDesc(a, b);
    });
    return sorted;
  }

  Widget _buildBody(String langCode, dynamic progress, AppLocalizations l10n) {
    final sorted = _activeFilter == 'all'
        ? _sortByStatus(_locations, progress)
        : _locations;

    final inProgressCount = _getInProgressIds(progress).length;
    final completedCount = _getCompletedIds(progress).length;
    final favCount = GameProgressService.favoriteLocationIds.length;
    final isOffline = MockBackend.lastFetchWasOffline;

    return Column(
      children: [
        // Banner only when we have cached content to show — otherwise the
        // empty state below already communicates the offline condition.
        if (isOffline && _allLocations.isNotEmpty) _buildOfflineBanner(langCode),
        // Search bar (collapsible)
        if (_searchExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: langCode == 'es' ? 'Buscar ubicaciones...' : 'Search locations...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass, size: 20, color: Colors.grey.shade400),
                suffixIcon: IconButton(
                  icon: Icon(PhosphorIconsBold.x, size: 16, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    _searchQuery = '';
                    setState(() => _searchExpanded = false);
                    _applyFilters();
                  },
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
        const SizedBox(height: 8),

        // Filter chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: langCode == 'es' ? 'Todos' : 'All',
                selected: _activeFilter == 'all' && _activeZone == null && _searchQuery.isEmpty,
                onTap: () => _onFilterChanged('all'),
              ),
              _FilterChip(
                label: langCode == 'es' ? 'Nuevos' : 'New',
                icon: PhosphorIconsBold.sparkle,
                selected: _activeFilter == 'new',
                onTap: () => _onFilterChanged('new'),
              ),
              if (inProgressCount > 0)
                _FilterChip(
                  label: langCode == 'es' ? 'En progreso' : 'In progress',
                  icon: PhosphorIconsBold.hourglass,
                  selected: _activeFilter == 'in_progress',
                  onTap: () => _onFilterChanged('in_progress'),
                ),
              if (completedCount > 0)
                _FilterChip(
                  label: langCode == 'es' ? 'Completados' : 'Completed',
                  icon: PhosphorIconsBold.checkCircle,
                  selected: _activeFilter == 'completed',
                  onTap: () => _onFilterChanged('completed'),
                ),
              if (favCount > 0)
                _FilterChip(
                  label: langCode == 'es' ? 'Favoritos' : 'Favorites',
                  icon: PhosphorIconsBold.heart,
                  selected: _activeFilter == 'favorites',
                  onTap: () => _onFilterChanged('favorites'),
                ),
              // Zone chips from config (only if they have locations)
              ..._config.zones
                .where((zone) => _allLocations.any((loc) => loc.region == zone.id))
                .map((zone) => _FilterChip(
                  label: langCode == 'es' ? (zone.name['es'] ?? zone.id) : (zone.name['en'] ?? zone.id),
                  icon: _zoneIcon(zone.icon),
                  selected: _activeZone == zone.id,
                  onTap: () => _onZoneChanged(_activeZone == zone.id ? null : zone.id),
                )),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Grid
        Expanded(
          child: _isLoading
              ? const Center(child: ClipOval(child: SizedBox(width: 95, height: 95, child: _LoaderGif())))
              : sorted.isEmpty
              ? _buildEmptyState(langCode, isOffline: isOffline)
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) =>
                      _buildLocationCard(sorted[index], langCode, progress),
                ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(langCode == 'es'
                  ? 'Necesitas ${loc.requiredPoints} puntos para desbloquear'
                  : 'Need ${loc.requiredPoints} points to unlock'),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _showDifficultyDialog(loc);
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
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
              imageUrl: loc.thumbnail,
              isUnlocked: isUnlocked,
              saturation: saturation,
            ),
            // Gradient at bottom for text + icons
            Positioned(
              left: 0, right: 0, bottom: 0, height: 90,
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
                          '${loc.requiredPoints} pts',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Onboarding play pulse — brand-new players only. Disappears
            // permanently after the first puzzle is completed.
            if (isUnlocked && progress.completedPuzzles.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _onboardingPulse,
                      builder: (_, __) {
                        final t = _onboardingPulse.value;
                        return Opacity(
                          opacity: 0.45 + 0.55 * t,
                          child: Container(
                            width: 54, height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsFill.play,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            // Favorite heart (unlocked only)
            if (isUnlocked)
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () async {
                    await GameProgressService.toggleFavorite(loc.id);
                    setState(() {});
                  },
                  child: Icon(
                    GameProgressService.isFavorite(loc.id)
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsBold.heart,
                    size: 22,
                    color: GameProgressService.isFavorite(loc.id)
                        ? Colors.redAccent
                        : Colors.white70,
                  ),
                ),
              ),
            // 100% completion badge (static, not tappable — card onTap opens difficulty dialog)
            if (isUnlocked && allCompleted)
              Positioned(
                top: 6, left: 6,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsBold.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            // Name
            Positioned(
              left: 10, bottom: 36, right: 10,
              child: Text(
                loc.getLocalizedName(langCode),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
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
    final isOffline = MockBackend.lastFetchWasOffline;
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(
        color: Colors.grey.shade200,
        child: const Center(child: AppLoader(size: 28)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOffline ? PhosphorIconsBold.cloudSlash : PhosphorIconsBold.image,
                size: 32,
                color: Colors.grey.shade600,
              ),
              if (isOffline) ...[
                const SizedBox(height: 4),
                Text(
                  Localizations.localeOf(context).languageCode == 'es'
                      ? 'Necesita conexión'
                      : 'Needs connection',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final PhosphorIconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentBlue : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: selected ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
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
      ),
    );
  }
}

class _TipSlide {
  final int difficulty;
  final String label;
  final String text;
  const _TipSlide({required this.difficulty, required this.label, required this.text});
}

/// Full-screen photo viewer with a toggleable tip card and optional silhouette
/// overlay. Used by `_showFullPhoto` from the map screen's completed-location
/// dialog. Mirrors the post-completion overlay on `puzzle_screen.dart`.
///
/// When the location has multiple completed difficulties with distinct tips,
/// the tip card becomes a horizontal PageView carousel. The silhouette is
/// per-slide: it appears only for difficulties where `showsSilhouetteAt` is
/// true, and soft-fades in/out as the user swipes between slides.
class _FullPhotoView extends StatefulWidget {
  final LocationModel location;
  final int difficulty;
  final String langCode;

  const _FullPhotoView({
    required this.location,
    required this.difficulty,
    required this.langCode,
  });

  @override
  State<_FullPhotoView> createState() => _FullPhotoViewState();
}

class _FullPhotoViewState extends State<_FullPhotoView> {
  bool _tipsVisible = true;
  bool _imageReady = false;
  late final PageController _pageController;
  late final List<_TipSlide> _slides;
  int _currentPage = 0;
  double _tipFontSize = SettingsService.tipFontSize;

  @override
  void initState() {
    super.initState();
    _slides = _buildSlides();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Build a deduplicated list of tip slides from the completed difficulties
  /// for this location. Difficulties without a tip are skipped; duplicate
  /// tip texts collapse into a single slide.
  List<_TipSlide> _buildSlides() {
    final loc = widget.location;
    final progress = GameProgressService.progress;
    final difficulties =
        loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels : [3];
    final completed = difficulties
        .where((d) => progress.completedPuzzles.containsKey('${loc.id}_$d'))
        .toList()
      ..sort();
    final labels = widget.langCode == 'es'
        ? const {3: 'Fácil', 4: 'Normal', 5: 'Difícil', 6: 'Experto'}
        : const {3: 'Easy', 4: 'Normal', 5: 'Hard', 6: 'Expert'};
    final seen = <String>{};
    final slides = <_TipSlide>[];
    for (final d in completed) {
      final text = loc.getLocalizedTipForDifficulty(widget.langCode, d);
      if (text.isEmpty) continue;
      if (seen.add(text)) {
        slides.add(_TipSlide(difficulty: d, label: labels[d] ?? '', text: text));
      }
    }
    return slides;
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Silhouette (both the toggle thumbnail and the big overlay) is a reward
    // for finishing Expert OR clearing every difficulty a location exposes
    // (locations without an expert level still earn the badge). Otherwise
    // fall back to a plain bulb and skip the overlay.
    final progressMap = GameProgressService.progress.completedPuzzles;
    final expertDone = progressMap.containsKey('${loc.id}_6');
    final locDiffs = loc.difficultyLevels.isNotEmpty
        ? loc.difficultyLevels
        : const [3];
    final allDifficultiesDone = locDiffs
        .every((d) => progressMap.containsKey('${loc.id}_$d'));
    final silhouetteEarned = expertDone || allDifficultiesDone;
    final showSilAny = silhouetteEarned &&
        _slides.any((s) => loc.showsSilhouetteAt(s.difficulty));
    final screenW = MediaQuery.of(context).size.width;
    final silW = screenW * 0.48;
    final silH = silW * 623 / 749;
    final showSil = _tipsVisible && showSilAny;
    return Scaffold(
      backgroundColor: AppTheme.seedColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            // Zoom & pan only unlock once the player earns the silhouette
            // reward (Expert cleared, or every difficulty cleared on locations
            // that don't ship an Expert level). Until then the image stays
            // static so zooming isn't a freebie after Easy.
            panEnabled: silhouetteEarned,
            scaleEnabled: silhouetteEarned,
            child: LayoutBuilder(
              builder: (ctx, box) {
                final imageUrl = loc.getImageForDifficulty(3);
                final crop = loc.hasPreRenderedCrop(3)
                    ? const [0.0, 0.0, 1.0, 1.0]
                    : loc.getCropForDifficulty(3);
                final cX = crop[0], cY = crop[1], cW = crop[2], cH = crop[3];
                final imgW = box.maxWidth / cW;
                final imgH = box.maxHeight / cH;
                return ClipRect(
                  child: OverflowBox(
                    maxWidth: imgW,
                    maxHeight: imgH,
                    alignment: Alignment(
                      cW >= 1 ? 0 : (2 * cX / (1 - cW) - 1),
                      cH >= 1 ? 0 : (2 * cY / (1 - cH) - 1),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: imgW,
                      height: imgH,
                      fit: BoxFit.cover,
                      imageBuilder: (ctx, imageProvider) {
                        if (!_imageReady) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _imageReady = true);
                          });
                        }
                        return Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          width: imgW,
                          height: imgH,
                        );
                      },
                      placeholder: (_, __) => const Center(
                        child: ClipOval(
                          child: SizedBox(width: 95, height: 95, child: _LoaderGif()),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        PhosphorIconsBold.imageSquare,
                        size: 48,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Close button — top-right
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsBold.x,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Tip toggle — just below the close button (only after content loads)
          if (_slides.isNotEmpty && _imageReady)
            Positioned(
              top: 64,
              right: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tipsVisible = !_tipsVisible),
                child: Opacity(
                  opacity: _tipsVisible ? 1.0 : 0.5,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: silhouetteEarned
                        ? Image.asset(
                            'assets/girl_cat_toggle.png',
                            fit: BoxFit.contain,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              PhosphorIconsBold.lightbulb,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          // Share button — third in the top-right stack, below tip-toggle.
          // Only visible once the photo has finished loading.
          if (_imageReady)
            Positioned(
              top: 116,
              right: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Share the tip for the currently-visible slide, not the
                  // difficulty the view was opened at — the user may have
                  // swiped the carousel to another level.
                  final diff = _slides.isNotEmpty
                      ? _slides[_currentPage].difficulty
                      : widget.difficulty;
                  ShareService.shareLocation(
                    context: context,
                    location: loc,
                    difficulty: diff,
                    langCode: widget.langCode,
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsBold.shareNetwork,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Tip carousel + silhouette — both anchored at bottom.
          // Toggle controls both tip AND silhouette. Hidden while loading.
          if (_imageReady)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            top: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: (_tipsVisible && _slides.isNotEmpty)
                        ? MediaQuery.withClampedTextScaling(
                            key: const ValueKey('tip-carousel-on'),
                            maxScaleFactor: 1.3,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                12, 0, 12, showSil ? 8 : 0,
                              ),
                              child: _TipCarousel(
                                slides: _slides,
                                langCode: widget.langCode,
                                controller: _pageController,
                                onPageChanged: (i) =>
                                    setState(() => _currentPage = i),
                                onClose: () =>
                                    setState(() => _tipsVisible = false),
                                fontSize: _tipFontSize,
                                onFontSizeChanged: (v) {
                                  setState(() => _tipFontSize = v);
                                  SettingsService.setTipFontSize(v);
                                },
                              ),
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('tip-carousel-off')),
                  ),
                ),
                // Silhouette — screen-fraction sized
                IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: showSil
                        ? SizedBox(
                            key: const ValueKey('sil-on'),
                            width: silW,
                            height: silH,
                            child: SvgPicture.asset(
                              'assets/girl_cat_with_bottom.svg',
                              fit: BoxFit.contain,
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('sil-off'),
                            width: silW,
                            height: silH,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable tip carousel used inside `_FullPhotoView`. Each page shows one
/// difficulty's tip on a light translucent card; the silhouette is a fixed
/// overlay drawn on top of the card by `_FullPhotoView`, not something the
/// carousel's text reserves space for. Dot indicators show carousel progress.
class _TipCarousel extends StatelessWidget {
  final List<_TipSlide> slides;
  final String langCode;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onClose;
  final double fontSize;
  final ValueChanged<double> onFontSizeChanged;

  const _TipCarousel({
    super.key,
    required this.slides,
    required this.langCode,
    required this.controller,
    required this.onPageChanged,
    this.onClose,
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            // Worst-case height: measure every slide's tip at its own
            // right-padding (silhouette on/off) and keep the tallest. This
            // makes the carousel auto-fit the longest tip — no scrolling,
            // no clipping — while every shorter tip gets the same card size.
            final tipStyle = GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              color: Colors.grey.shade900,
              height: 1.4,
            );
            // Tip uses the full card width (minus horizontal padding).
            // The silhouette is a fixed overlay drawn on top of the card,
            // not something the text needs to reserve space for.
            final textScaler = MediaQuery.textScalerOf(ctx);
            final availW = constraints.maxWidth - 14 - 10;
            double tallestTip = 0;
            for (var i = 0; i < slides.length; i++) {
              final tp = TextPainter(
                text: TextSpan(text: slides[i].text, style: tipStyle),
                textDirection: TextDirection.ltr,
                textScaler: textScaler,
              )..layout(maxWidth: availW > 0 ? availW : 1);
              if (tp.height > tallestTip) tallestTip = tp.height;
            }
            // Pill + gap + vertical padding (top 10, bottom 12) around body.
            const verticalPad = 10.0 + 12.0;
            final scaleFactor = textScaler.scale(14) / 14;
            // pill row: max(pill height, X icon with padding) + gap
            final pillH = 22.0 * scaleFactor;
            const xIconH = 16.0 + 4.0 + 4.0; // icon + padding top/bottom
            final labelBlock = (pillH > xIconH ? pillH : xIconH) + 8.0;
            const sliderRowH = 32.0; // SizedBox(28) + SizedBox gap(4)
            final pageH = (tallestTip + labelBlock + verticalPad + sliderRowH).ceilToDouble() + 20;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: pageH,
                  child: PageView.builder(
                    controller: controller,
                    itemCount: slides.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (_, i) {
                      final slide = slides[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                _buildLevelPill(
                                  difficulty: slide.difficulty,
                                  langCode: langCode,
                                ),
                                const Spacer(),
                                if (onClose != null)
                                  GestureDetector(
                                    onTap: onClose,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        PhosphorIconsBold.x,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slide.text,
                              style: tipStyle,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 28,
                              child: Row(
                                children: [
                                  Text(
                                    'A',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                                overlayRadius: 12),
                                        activeTrackColor: Colors.grey.shade400,
                                        inactiveTrackColor:
                                            Colors.grey.shade200,
                                        thumbColor: Colors.grey.shade500,
                                        overlayColor: Colors.grey.shade300
                                            .withValues(alpha: 0.4),
                                      ),
                                      child: Slider(
                                        value: fontSize,
                                        min: 12.0,
                                        max: 22.0,
                                        divisions: 10,
                                        onChanged: onFontSizeChanged,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'A',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 17,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            if (slides.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 2),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) {
                    final current = (controller.hasClients &&
                            controller.page != null)
                        ? controller.page!.round()
                        : 0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(slides.length, (i) {
                        final active = i == current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? AppTheme.trophyGold
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Optimized looping gif loader, pre-rendered at 100x100.
class _LoaderGif extends StatelessWidget {
  const _LoaderGif();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/loading_loop.gif',
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }
}

/// Identifies which optional hint is being toggled — lets the notification
/// helper pick the right bilingual explanation.
enum _HintKind { lock, multi, reference }

/// Top-screen notification for hint toggles. Visual parity with the trophy
/// notifications (dark teal card, gold icon, white bold text). Uses the
/// root overlay so it sits above the difficulty modal, and keeps a single
/// in-flight entry — a fresh call replaces the current notification so the
/// player only ever sees the latest toggle's explanation.
class _HintNotificationHost {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required PhosphorIconData icon,
    required String text,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _current?.remove();
    _timer?.cancel();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HintNotificationCard(icon: icon, text: text),
    );
    _current = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (_current == entry) {
        entry.remove();
        _current = null;
      }
    });
  }
}

class _HintNotificationCard extends StatefulWidget {
  final PhosphorIconData icon;
  final String text;
  const _HintNotificationCard({required this.icon, required this.text});

  @override
  State<_HintNotificationCard> createState() => _HintNotificationCardState();
}

class _HintNotificationCardState extends State<_HintNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A4B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 26, color: AppTheme.trophyGold),
                const SizedBox(height: 6),
                Text(
                  widget.text,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill showing the running total of hint penalties. Invisible when 0.
class _HintPenaltyBadge extends StatelessWidget {
  final int penalty;
  final String langCode;
  const _HintPenaltyBadge({required this.penalty, required this.langCode});

  @override
  Widget build(BuildContext context) {
    if (penalty <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Text(
        '−$penalty pts',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.red.shade400,
        ),
      ),
    );
  }
}
