import 'dart:async';
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
  List<LocationModel> _allLocations = []; // cached for profile/puzzle
  GameConfig _config = GameConfig.fromJson({});
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  // Filters
  String _activeFilter = 'all'; // 'all','new','in_progress','completed','favorites'
  String? _activeZone;
  String _searchQuery = '';
  Timer? _searchDebounce;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
    _initAuth();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _initAuth() async {
    try {
      if (!await AuthService.isSignedIn()) await AuthService.signIn();
    } catch (_) {}
  }

  Future<void> _initData() async {
    try {
      final config = await MockBackend.fetchGameConfig();
      if (mounted) {
        setState(() { _config = config; });
      }
      await _loadLocations();
      // Cache all locations for profile/puzzle screens
      _allLocations = await MockBackend.fetchLocations();
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _locations = [];
      _currentPage = 0;
      _hasMore = true;
    });
    await _fetchPage(0);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    // ID-based filters return all at once, no pagination
    if (['in_progress', 'completed', 'favorites'].contains(_activeFilter)) return;
    setState(() { _isLoadingMore = true; });
    await _fetchPage(_currentPage + 1);
    setState(() { _isLoadingMore = false; });
  }

  Future<void> _fetchPage(int page) async {
    try {
      PaginatedLocations result;
      final progress = GameProgressService.progress;

      if (_activeFilter == 'in_progress') {
        final ids = _getInProgressIds(progress);
        if (ids.isEmpty) {
          if (mounted) setState(() { _locations = []; _isLoading = false; _hasMore = false; });
          return;
        }
        result = await MockBackend.fetchLocationsPaginated(ids: ids);
      } else if (_activeFilter == 'completed') {
        final ids = _getCompletedIds(progress);
        if (ids.isEmpty) {
          if (mounted) setState(() { _locations = []; _isLoading = false; _hasMore = false; });
          return;
        }
        result = await MockBackend.fetchLocationsPaginated(ids: ids);
      } else if (_activeFilter == 'favorites') {
        final ids = GameProgressService.favoriteLocationIds;
        if (ids.isEmpty) {
          if (mounted) setState(() { _locations = []; _isLoading = false; _hasMore = false; });
          return;
        }
        result = await MockBackend.fetchLocationsPaginated(ids: ids);
      } else {
        result = await MockBackend.fetchLocationsPaginated(
          page: page,
          limit: _pageSize,
          zone: _activeZone,
          query: _searchQuery.isNotEmpty ? _searchQuery : null,
          isNew: _activeFilter == 'new' ? true : null,
        );
      }

      if (mounted) {
        setState(() {
          if (page == 0) {
            _locations = result.data;
          } else {
            _locations.addAll(result.data);
          }
          _currentPage = page;
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  List<String> _getInProgressIds(dynamic progress) {
    // Locations with some but not all difficulties completed
    final Map<String, int> completedByLoc = {};
    for (final key in progress.completedPuzzles.keys) {
      final locId = key.toString().split('_').first;
      completedByLoc[locId] = (completedByLoc[locId] ?? 0) + 1;
    }
    return completedByLoc.entries
        .where((e) => e.value > 0 && e.value < 4) // less than 4 difficulties
        .map((e) => e.key)
        .toList();
  }

  List<String> _getCompletedIds(dynamic progress) {
    final Map<String, int> completedByLoc = {};
    for (final key in progress.completedPuzzles.keys) {
      final locId = key.toString().split('_').first;
      completedByLoc[locId] = (completedByLoc[locId] ?? 0) + 1;
    }
    return completedByLoc.entries
        .where((e) => e.value >= 4) // all 4 difficulties
        .map((e) => e.key)
        .toList();
  }

  void _onFilterChanged(String filter) {
    if (filter == _activeFilter) return;
    _activeFilter = filter;
    _activeZone = null;
    _searchQuery = '';
    _searchController.clear();
    _loadLocations();
  }

  void _onZoneChanged(String? zone) {
    _activeZone = zone;
    _activeFilter = 'all';
    _searchQuery = '';
    _searchController.clear();
    _loadLocations();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = value;
      _activeFilter = 'all';
      _activeZone = null;
      _loadLocations();
    });
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
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 100),
        transitionsBuilder: (ctx, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (ctx, _, __) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(
                    loc.image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      PhosphorIconsBold.imageSquare, size: 48, color: Colors.white38,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(PhosphorIconsBold.x, size: 22, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
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
          allLocations: _allLocations,
        ),
      ),
    );
    if (mounted) {
      // Refresh to pick up new progress, favorites, etc.
      _loadLocations();
      // Update allLocations cache too
      MockBackend.fetchLocations().then((locs) {
        if (mounted) _allLocations = locs;
      });
    }
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
            onPressed: () async {
              await AudioService.toggleMute();
              setState(() {});
            },
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
              MaterialPageRoute(builder: (_) => ProfileScreen(config: _config, allLocations: _allLocations)),
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
      return 0;
    });
    return sorted;
  }

  Widget _buildBody(String langCode, dynamic progress, AppLocalizations l10n) {
    final sorted = _activeFilter == 'all'
        ? _sortByStatus(_locations, progress)
        : _locations;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: langCode == 'es' ? 'Buscar ubicaciones...' : 'Search locations...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400),
              prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass, size: 20, color: Colors.grey.shade400),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(PhosphorIconsBold.x, size: 16, color: Colors.grey.shade400),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _loadLocations();
                      },
                    )
                  : null,
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
              _FilterChip(
                label: langCode == 'es' ? 'En progreso' : 'In progress',
                icon: PhosphorIconsBold.hourglass,
                selected: _activeFilter == 'in_progress',
                onTap: () => _onFilterChanged('in_progress'),
              ),
              _FilterChip(
                label: langCode == 'es' ? 'Completados' : 'Completed',
                icon: PhosphorIconsBold.checkCircle,
                selected: _activeFilter == 'completed',
                onTap: () => _onFilterChanged('completed'),
              ),
              _FilterChip(
                label: langCode == 'es' ? 'Favoritos' : 'Favorites',
                icon: PhosphorIconsBold.heart,
                selected: _activeFilter == 'favorites',
                onTap: () => _onFilterChanged('favorites'),
              ),
              // Zone chips from config
              ..._config.zones.map((zone) => _FilterChip(
                label: langCode == 'es' ? (zone.name['es'] ?? zone.id) : (zone.name['en'] ?? zone.id),
                selected: _activeZone == zone.id,
                onTap: () => _onZoneChanged(_activeZone == zone.id ? null : zone.id),
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Grid
        Expanded(
          child: sorted.isEmpty && !_isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsBold.magnifyingGlass, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        langCode == 'es' ? 'Sin resultados' : 'No results',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: sorted.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= sorted.length) {
                      // Loading indicator at bottom
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    return _buildLocationCard(sorted[index], langCode, progress);
                  },
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
          final pts = _getPointsToUnlock(loc);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(langCode == 'es'
                  ? '$pts puntos más para desbloquear'
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
    return Padding(
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
