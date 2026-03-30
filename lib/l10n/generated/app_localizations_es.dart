// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Explorador Puzzles Chile';

  @override
  String get playButton => 'Jugar';

  @override
  String get difficultyBeginner => 'Principiante (3x3)';

  @override
  String get difficultyEasy => 'Fácil (4x4)';

  @override
  String get difficultyMedium => 'Medio (5x5)';

  @override
  String get difficultyHard => 'Difícil (6x6)';

  @override
  String get difficultyExpert => 'Experto (8x8)';

  @override
  String get difficultyMaster => 'Maestro (10x10)';

  @override
  String get unlockNext => 'Desbloquear Siguiente';

  @override
  String get returnToMap => 'Volver al mapa';

  @override
  String get loading => 'Cargando...';

  @override
  String get puzzleCompleted => '¡Puzzle completado!';
}
