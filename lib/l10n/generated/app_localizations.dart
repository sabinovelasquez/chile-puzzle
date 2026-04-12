import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Zoom-In Chile'**
  String get appTitle;

  /// No description provided for @playButton.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get playButton;

  /// No description provided for @difficultyBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner (3x3)'**
  String get difficultyBeginner;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy (4x4)'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (5x5)'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard (6x6)'**
  String get difficultyHard;

  /// No description provided for @difficultyExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert (8x8)'**
  String get difficultyExpert;

  /// No description provided for @difficultyMaster.
  ///
  /// In en, this message translates to:
  /// **'Master (10x10)'**
  String get difficultyMaster;

  /// No description provided for @unlockNext.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get unlockNext;

  /// No description provided for @returnToMap.
  ///
  /// In en, this message translates to:
  /// **'Return to map'**
  String get returnToMap;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @puzzleCompleted.
  ///
  /// In en, this message translates to:
  /// **'Puzzle Completed!'**
  String get puzzleCompleted;

  /// No description provided for @totalPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get totalPoints;

  /// No description provided for @pointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points Earned'**
  String get pointsEarned;

  /// No description provided for @timeBonus.
  ///
  /// In en, this message translates to:
  /// **'Time Bonus'**
  String get timeBonus;

  /// No description provided for @efficiencyBonus.
  ///
  /// In en, this message translates to:
  /// **'Efficiency Bonus'**
  String get efficiencyBonus;

  /// No description provided for @trophies.
  ///
  /// In en, this message translates to:
  /// **'Trophies'**
  String get trophies;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @zoneLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get zoneLocked;

  /// No description provided for @zoneUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get zoneUnlocked;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @newTrophy.
  ///
  /// In en, this message translates to:
  /// **'New Trophy!'**
  String get newTrophy;

  /// No description provided for @puzzlesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Puzzles'**
  String get puzzlesCompleted;

  /// No description provided for @bestTime.
  ///
  /// In en, this message translates to:
  /// **'Best Time'**
  String get bestTime;

  /// No description provided for @newLocationsWeekly.
  ///
  /// In en, this message translates to:
  /// **'New locations every week — keep exploring!'**
  String get newLocationsWeekly;

  /// No description provided for @clearProgress.
  ///
  /// In en, this message translates to:
  /// **'Clear progress'**
  String get clearProgress;

  /// No description provided for @clearProgressWarning.
  ///
  /// In en, this message translates to:
  /// **'This will delete all your points, trophies and progress. Are you sure?'**
  String get clearProgressWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Zoom-In Chile was born from our love of traveling and discovering. We built it together, Xime and I, driven by curiosity to explore every corner — the architecture, the history, the little details you only notice when you stop and look.\n\nAll the pictures are taken by us during our travels. This game is our way of sharing those places and the joy of exploring them.\n\nWe hope you enjoy discovering Chile as much as we enjoyed traveling it.'**
  String get aboutDescription;

  /// No description provided for @aboutSignature.
  ///
  /// In en, this message translates to:
  /// **'— Sabino'**
  String get aboutSignature;

  /// No description provided for @photoCredits.
  ///
  /// In en, this message translates to:
  /// **'Photography: Sabino & Xime'**
  String get photoCredits;

  /// No description provided for @tipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tipsTitle;

  /// No description provided for @tipForDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Tip for {level}'**
  String tipForDifficulty(String level);

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupAndRestore;

  /// No description provided for @backupProgress.
  ///
  /// In en, this message translates to:
  /// **'Backup progress'**
  String get backupProgress;

  /// No description provided for @restoreProgress.
  ///
  /// In en, this message translates to:
  /// **'Restore progress'**
  String get restoreProgress;

  /// No description provided for @generateBackupCode.
  ///
  /// In en, this message translates to:
  /// **'Generate code'**
  String get generateBackupCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @emailCode.
  ///
  /// In en, this message translates to:
  /// **'Email it to me'**
  String get emailCode;

  /// No description provided for @emailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'you@email.com'**
  String get emailPlaceholder;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Email sent'**
  String get emailSent;

  /// No description provided for @emailFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send email'**
  String get emailFailed;

  /// No description provided for @enterBackupCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your code'**
  String get enterBackupCode;

  /// No description provided for @backupCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'XXXX-XXXX'**
  String get backupCodePlaceholder;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore progress?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current progress with the one from the code. You cannot undo this.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreAction;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create backup'**
  String get backupFailed;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Progress restored'**
  String get restoreSuccess;

  /// No description provided for @backupCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get backupCodeInvalid;

  /// No description provided for @backupExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String backupExpiresOn(String date);

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Save your progress with a short code. Use it on another device to restore it.'**
  String get backupIntro;

  /// No description provided for @backupPrivacyWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this code can restore your progress.'**
  String get backupPrivacyWarning;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
