import 'package:flutter/material.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/features/puzzle/puzzle_screen.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:chile_puzzle/features/auth/auth_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LocationModel> _locations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      bool signedIn = await AuthService.isSignedIn();
      if (!signedIn) {
        await AuthService.signIn();
      }
    } catch (e) {
      debugPrint('Auth error: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await MockBackend.fetchLocations();
      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Could not load locations',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _isLoading = true; _error = null; });
                          _loadLocations();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _locations.isEmpty
                  ? const Center(child: Text('No locations found'))
                  : ListView.builder(
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final loc = _locations[index];
                        final difficulty = loc.difficultyLevels.isNotEmpty
                            ? loc.difficultyLevels.first
                            : 4;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: loc.image.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      loc.image,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.landscape, size: 40),
                                    ),
                                  )
                                : const Icon(Icons.landscape, size: 40),
                            title: Text(loc.getLocalizedName(langCode)),
                            subtitle: Text(
                                '${loc.region} • ${difficulty}x$difficulty'),
                            trailing:
                                const Icon(Icons.play_circle_outline, size: 32),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PuzzleScreen(
                                    location: loc,
                                    gridRows: difficulty,
                                    gridCols: difficulty,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
