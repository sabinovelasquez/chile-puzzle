import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/models/game_config.dart';
import 'package:chile_puzzle/core/models/zone_model.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/features/puzzle/puzzle_screen.dart';
import 'package:chile_puzzle/features/puzzle/icon_mapping.dart';
import 'package:chile_puzzle/features/profile/profile_screen.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:chile_puzzle/features/auth/auth_service.dart';
import 'package:chile_puzzle/main.dart';

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

  Future<void> _openPuzzle(LocationModel loc) async {
    final difficulty = loc.difficultyLevels.isNotEmpty ? loc.difficultyLevels.first : 3;
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

  void _toggleLanguage() {
    // Cycle locale between EN and ES
    final currentLocale = Localizations.localeOf(context);
    final newLocale = currentLocale.languageCode == 'es'
        ? const Locale('en')
        : const Locale('es');
    // Force rebuild via the app-level locale
    ChilePuzzleApp.setLocale(context, newLocale);
  }

  void _showScoringHelp() {
    final scoring = _config.scoring;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scoring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _helpRow(Icons.grid_view, 'Base points',
              scoring.basePoints.entries.map((e) => '${e.key}-col: ${e.value} pts').join(', ')),
            const SizedBox(height: 10),
            _helpRow(Icons.timer_outlined, 'Time bonus',
              '${scoring.timeBonusPoints} pts if under ${scoring.timeBonusThresholdSecs}s'),
            const SizedBox(height: 10),
            _helpRow(Icons.bolt_outlined, 'Efficiency bonus',
              '+${scoring.moveEfficiencyBonusPercent}% if few moves'),
            const SizedBox(height: 10),
            _helpRow(Icons.lock_open_outlined, 'Unlock zones',
              'Accumulate points to unlock new regions'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1B3A4B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;
    final progress = GameProgressService.progress;
    final unlockedZoneIds = GameProgressService.getUnlockedZoneIds(_config.zones);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          // Help
          IconButton(
            onPressed: _showScoringHelp,
            icon: Icon(Icons.help_outline, size: 22, color: Colors.grey.shade500),
            tooltip: 'Scoring help',
          ),
          // Language toggle
          IconButton(
            onPressed: _toggleLanguage,
            icon: Text(
              langCode.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            tooltip: 'Change language',
          ),
          // Points → profile
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(config: _config)),
            ).then((_) { if (mounted) setState(() {}); }),
            icon: Icon(Icons.emoji_events, size: 20, color: AppTheme.trophyGold),
            label: Text(
              '${progress.totalPoints}',
              style: TextStyle(
                color: AppTheme.trophyGold,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildZoneList(langCode, unlockedZoneIds, progress),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
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

  Widget _buildZoneList(String langCode, List<String> unlockedZoneIds, dynamic progress) {
    final zones = List<ZoneModel>.from(_config.zones)..sort((a, b) => a.order.compareTo(b.order));
    final locsByZone = <String, List<LocationModel>>{};
    for (final loc in _locations) {
      locsByZone.putIfAbsent(loc.region, () => []).add(loc);
    }

    if (zones.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _locations.map((loc) => _buildLocationCard(loc, langCode, progress)).toList(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: zones.length,
      itemBuilder: (context, index) {
        final zone = zones[index];
        final isUnlocked = unlockedZoneIds.contains(zone.id);
        final zoneLocs = locsByZone[zone.id] ?? [];
        final pointsNeeded = zone.requiredPoints - GameProgressService.totalPoints;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? const Color(0xFF1B3A4B).withOpacity(0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isUnlocked ? mapIcon(zone.icon) : Icons.lock_outline,
                      size: 18,
                      color: isUnlocked ? const Color(0xFF1B3A4B) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      zone.getLocalizedName(langCode),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isUnlocked ? const Color(0xFF1B3A4B) : Colors.grey,
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pointsNeeded pts',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            if (!isUnlocked)
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$pointsNeeded more points to unlock'), duration: const Duration(seconds: 2)),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Text(
                      '${zoneLocs.length} locations locked',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

            if (isUnlocked)
              ...zoneLocs.map((loc) => _buildLocationCard(loc, langCode, progress)),
          ],
        );
      },
    );
  }

  Widget _buildLocationCard(LocationModel loc, String langCode, dynamic progress) {
    final isCompleted = progress.isLocationCompleted(loc.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPuzzle(loc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image — blur if not completed
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: ImageFiltered(
                    imageFilter: isCompleted
                        ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                        : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Image.network(
                      loc.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade100,
                        child: Icon(Icons.landscape, size: 40, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ),
                if (isCompleted)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.check, size: 16, color: Color(0xFF4CAF50)),
                    ),
                  ),
                if (!isCompleted)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, size: 24, color: Color(0xFF1B3A4B)),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(
                loc.getLocalizedName(langCode),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

