// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zoom-In Chile';

  @override
  String get playButton => 'Begin';

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
  String get unlockNext => 'Continue';

  @override
  String get returnToMap => 'Return to map';

  @override
  String get loading => 'Loading...';

  @override
  String get puzzleCompleted => 'Puzzle Completed!';

  @override
  String get totalPoints => 'Points';

  @override
  String get pointsEarned => 'Points Earned';

  @override
  String get timeBonus => 'Time Bonus';

  @override
  String get efficiencyBonus => 'Efficiency Bonus';

  @override
  String get trophies => 'Trophies';

  @override
  String get profile => 'Profile';

  @override
  String get zoneLocked => 'Locked';

  @override
  String get zoneUnlocked => 'Unlocked';

  @override
  String get share => 'Share';

  @override
  String get moves => 'Moves';

  @override
  String get time => 'Time';

  @override
  String get completed => 'Completed';

  @override
  String get newTrophy => 'New Trophy!';

  @override
  String get puzzlesCompleted => 'Puzzles';

  @override
  String get bestTime => 'Best Time';

  @override
  String get newLocationsWeekly => 'New locations every week — keep exploring!';

  @override
  String get clearProgress => 'Clear progress';

  @override
  String get clearProgressWarning =>
      'This will delete all your points, trophies and progress. Are you sure?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'Zoom-In Chile was born from our love of traveling and discovering. We built it together, Ximena and I, driven by curiosity to explore every corner — the architecture, the history, the little details you only notice when you stop and look.\n\nEvery photograph was taken by us during our travels. This game is our way of sharing those places and the joy of exploring them.\n\nWe hope you enjoy discovering Chile as much as we enjoyed traveling it.';

  @override
  String get aboutSignature => '— Sabino';

  @override
  String get photoCredits => 'Photography: Sabino & Ximena';

  @override
  String get tipsTitle => 'Tips';

  @override
  String tipForDifficulty(String level) {
    return 'Tip for $level';
  }

  @override
  String get backupAndRestore => 'Backup & restore';

  @override
  String get backupProgress => 'Backup progress';

  @override
  String get restoreProgress => 'Restore progress';

  @override
  String get generateBackupCode => 'Generate code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get emailCode => 'Email it to me';

  @override
  String get emailPlaceholder => 'you@email.com';

  @override
  String get emailSent => 'Email sent';

  @override
  String get emailFailed => 'Could not send email';

  @override
  String get enterBackupCode => 'Enter your code';

  @override
  String get backupCodePlaceholder => 'XXXX-XXXX';

  @override
  String get restoreConfirmTitle => 'Restore progress?';

  @override
  String get restoreConfirmBody =>
      'This will overwrite your current progress with the one from the code. You cannot undo this.';

  @override
  String get restoreAction => 'Restore';

  @override
  String get backupSuccess => 'Backup created';

  @override
  String get backupFailed => 'Could not create backup';

  @override
  String get restoreSuccess => 'Progress restored';

  @override
  String get backupCodeInvalid => 'Invalid or expired code';

  @override
  String backupExpiresOn(String date) {
    return 'Valid until $date';
  }

  @override
  String get backupIntro =>
      'Save your progress with a short code. Use it on another device to restore it.';

  @override
  String get backupPrivacyWarning =>
      'Anyone with this code can restore your progress.';
}
