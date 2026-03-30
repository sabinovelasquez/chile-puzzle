import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:chile_puzzle/core/models/location_model.dart';
import 'package:chile_puzzle/core/services/mock_backend.dart';
import 'package:chile_puzzle/features/puzzle/puzzle_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chile_puzzle/features/auth/auth_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final LatLng _chileCenter = const LatLng(-35.6751, -71.5430);
  
  List<LocationModel> _locations = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _initAuth();
  }

  Future<void> _initAuth() async {
    bool signedIn = await AuthService.isSignedIn();
    if (!signedIn) {
      await AuthService.signIn();
    }
  }

  Future<void> _loadLocations() async {
    final locations = await MockBackend.fetchLocations();
    if (mounted) {
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
      if (_markers.isEmpty) {
        _updateMarkers();
      }
    }
  }
  
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _updateMarkers();
  }

  void _updateMarkers() {
    if (!mounted || _locations.isEmpty) return;
    
    // Defer context access until build if needed, but since this is called 
    // after layout/init, context should be available.
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    
    final langCode = Localizations.localeOf(context).languageCode;
    
    final newMarkers = _locations.map((loc) {
      return Marker(
        markerId: MarkerId(loc.id),
        position: LatLng(loc.latitude, loc.longitude),
        infoWindow: InfoWindow(
          title: loc.getLocalizedName(langCode),
          snippet: '${l10n.playButton} • ${loc.region}',
          onTap: () {
            int difficulty = (loc.difficultyLevels.isNotEmpty) ? loc.difficultyLevels.first : 4;
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
    }).toSet();

    setState(() {
      _markers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2)
              ),
            )
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _chileCenter,
          zoom: 4.0,
        ),
        markers: _markers,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
      ),
    );
  }
}
