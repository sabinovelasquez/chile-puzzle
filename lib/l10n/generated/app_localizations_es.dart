// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Zoom-In Chile';

  @override
  String get playButton => 'Comenzar';

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
  String get unlockNext => 'Seguir';

  @override
  String get returnToMap => 'Volver al mapa';

  @override
  String get loading => 'Cargando...';

  @override
  String get puzzleCompleted => '¡Puzzle completado!';

  @override
  String get totalPoints => 'Puntos';

  @override
  String get pointsEarned => 'Puntos Obtenidos';

  @override
  String get timeBonus => 'Bonus de Tiempo';

  @override
  String get efficiencyBonus => 'Bonus de Eficiencia';

  @override
  String get trophies => 'Trofeos';

  @override
  String get profile => 'Perfil';

  @override
  String get zoneLocked => 'Bloqueado';

  @override
  String get zoneUnlocked => 'Desbloqueado';

  @override
  String get share => 'Compartir';

  @override
  String get moves => 'Movimientos';

  @override
  String get time => 'Tiempo';

  @override
  String get completed => 'Completado';

  @override
  String get newTrophy => '¡Nuevo Trofeo!';

  @override
  String get puzzlesCompleted => 'Puzzles';

  @override
  String get bestTime => 'Mejor Tiempo';

  @override
  String get newLocationsWeekly =>
      'Nuevas ubicaciones cada semana — ¡sigue explorando!';

  @override
  String get clearProgress => 'Borrar progreso';

  @override
  String get clearProgressWarning =>
      'Esto borrará todos tus puntos, trofeos y progreso. ¿Estás seguro?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Borrar';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutDescription =>
      'Zoom-In Chile nació del amor por recorrer y descubrir. Lo hicimos juntos, Xime y yo, movidos por la curiosidad de conocer cada rincón, su arquitectura, su historia y esos detalles que solo se ven cuando uno se detiene a mirar.\n\nTodas las fotografías son tomadas por nosotros durante nuestros viajes. Este juego es nuestra forma de compartir esos lugares y la alegría de explorarlos.\n\nEsperamos que disfrutes descubriendo Chile tanto como nosotros disfrutamos recorriéndolo.';

  @override
  String get aboutSignature => '— Sabino';

  @override
  String get photoCredits => 'Fotografía: Sabino & Xime';

  @override
  String get tipsTitle => 'Pistas';

  @override
  String tipForDifficulty(String level) {
    return 'Pista para $level';
  }

  @override
  String get backupAndRestore => 'Respaldo y restauración';

  @override
  String get backupProgress => 'Respaldar progreso';

  @override
  String get restoreProgress => 'Restaurar progreso';

  @override
  String get generateBackupCode => 'Generar código';

  @override
  String get copyCode => 'Copiar código';

  @override
  String get codeCopied => 'Código copiado';

  @override
  String get emailCode => 'Enviar por correo';

  @override
  String get emailPlaceholder => 'tu@correo.cl';

  @override
  String get emailSent => 'Correo enviado';

  @override
  String get emailFailed => 'No se pudo enviar el correo';

  @override
  String get enterBackupCode => 'Ingresa tu código';

  @override
  String get backupCodePlaceholder => 'XXXX-XXXX';

  @override
  String get restoreConfirmTitle => '¿Restaurar progreso?';

  @override
  String get restoreConfirmBody =>
      'Esto sobrescribirá tu progreso actual con el del código ingresado. No podrás deshacerlo.';

  @override
  String get restoreAction => 'Restaurar';

  @override
  String get backupSuccess => 'Respaldo creado';

  @override
  String get backupFailed => 'No se pudo crear el respaldo';

  @override
  String get restoreSuccess => 'Progreso restaurado';

  @override
  String get backupCodeInvalid => 'Código inválido o expirado';

  @override
  String backupExpiresOn(String date) {
    return 'Válido hasta $date';
  }

  @override
  String get backupIntro =>
      'Guarda tu progreso con un código corto. Úsalo en otro dispositivo para recuperarlo.';

  @override
  String get backupPrivacyWarning =>
      'Cualquiera con este código puede restaurar tu progreso.';
}
