// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chile Puzzle Explorer';

  @override
  String get playButton => 'Play';

  @override
  String get difficultyBeginner => 'Beginner (3x3)';

  @override
  String get difficultyEasy => 'Easy (4x4)';

  @override
  String get difficultyMedium => 'Medium (5x5)';

  @override
  String get difficultyHard => 'Hard (6x6)';

  @override
  String get difficultyExpert => 'Expert (8x8)';

  @override
  String get difficultyMaster => 'Master (10x10)';

  @override
  String get unlockNext => 'Unlock Next';

  @override
  String get returnToMap => 'Return to map';

  @override
  String get loading => 'Loading...';

  @override
  String get puzzleCompleted => 'Puzzle Completed!';
}
