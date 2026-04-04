import 'package:flutter/material.dart';
import 'package:chile_puzzle/l10n/generated/app_localizations.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';
import 'package:chile_puzzle/core/services/game_progress_service.dart';
import 'features/map/map_screen.dart';
import 'features/ads/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdService.initialize();
  AdService.loadInterstitial();
  await GameProgressService.initialize();
  runApp(const ChilePuzzleApp());
}

class ChilePuzzleApp extends StatefulWidget {
  const ChilePuzzleApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_ChilePuzzleAppState>()?._setLocale(locale);
  }

  @override
  State<ChilePuzzleApp> createState() => _ChilePuzzleAppState();
}

class _ChilePuzzleAppState extends State<ChilePuzzleApp> {
  Locale? _locale;

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chile Puzzle Explorer',
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MapScreen(),
    );
  }
}
