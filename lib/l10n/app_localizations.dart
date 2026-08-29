import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone ADAS'**
  String get appTitle;

  /// No description provided for @hudSpeedUnit.
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get hudSpeedUnit;

  /// No description provided for @hudDistanceToLead.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get hudDistanceToLead;

  /// No description provided for @hudRequiredGap.
  ///
  /// In en, this message translates to:
  /// **'required {meters} m'**
  String hudRequiredGap(int meters);

  /// No description provided for @hudNoLeadVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle ahead'**
  String get hudNoLeadVehicle;

  /// No description provided for @warnKeepDistance.
  ///
  /// In en, this message translates to:
  /// **'Keep your distance'**
  String get warnKeepDistance;

  /// No description provided for @warnCollision.
  ///
  /// In en, this message translates to:
  /// **'Brake! Collision risk'**
  String get warnCollision;

  /// No description provided for @warnLeadDeparted.
  ///
  /// In en, this message translates to:
  /// **'Vehicle ahead is moving'**
  String get warnLeadDeparted;

  /// No description provided for @hudOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get hudOffline;

  /// No description provided for @hudWeatherUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable'**
  String get hudWeatherUnavailable;

  /// No description provided for @hudLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get hudLocating;

  /// No description provided for @screenshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Screenshot saved'**
  String get screenshotSaved;

  /// No description provided for @screenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save screenshot'**
  String get screenshotFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (day/night by sun)'**
  String get settingsThemeAuto;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @camPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required for distance measurement'**
  String get camPermissionNeeded;

  /// No description provided for @locPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for speed and weather'**
  String get locPermissionNeeded;

  /// No description provided for @mockModeBadge.
  ///
  /// In en, this message translates to:
  /// **'MOCK DATA'**
  String get mockModeBadge;

  /// No description provided for @toolbarRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get toolbarRecord;

  /// No description provided for @toolbarPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get toolbarPhoto;

  /// No description provided for @toolbarSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get toolbarSettings;

  /// No description provided for @toolbarHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get toolbarHistory;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @hudCameraPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Live camera arrives in phase 2 — mock data for now'**
  String get hudCameraPlaceholder;

  /// No description provided for @settingsCalibration.
  ///
  /// In en, this message translates to:
  /// **'Calibrate distance'**
  String get settingsCalibration;

  /// No description provided for @calibIntro.
  ///
  /// In en, this message translates to:
  /// **'Mount the phone firmly on its holder first. Then aim the camera at a parked car straight ahead. You will measure twice: at 10 m and at 30 m (lane dashes are 3 m long with 6 m gaps — handy as a ruler).'**
  String get calibIntro;

  /// No description provided for @calibStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get calibStart;

  /// No description provided for @calibPointPrompt.
  ///
  /// In en, this message translates to:
  /// **'Point {index}/2 — target car at {meters} m'**
  String calibPointPrompt(int index, int meters);

  /// No description provided for @calibDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected: {meters} m'**
  String calibDetected(String meters);

  /// No description provided for @calibNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle detected — aim at the car'**
  String get calibNoVehicle;

  /// No description provided for @calibSample.
  ///
  /// In en, this message translates to:
  /// **'Sample (3 s)'**
  String get calibSample;

  /// No description provided for @calibSampling.
  ///
  /// In en, this message translates to:
  /// **'Hold still — sampling…'**
  String get calibSampling;

  /// No description provided for @calibErrTooFew.
  ///
  /// In en, this message translates to:
  /// **'Not enough stable detections — try again'**
  String get calibErrTooFew;

  /// No description provided for @calibErrUnstable.
  ///
  /// In en, this message translates to:
  /// **'Readings unstable — keep the phone and target still'**
  String get calibErrUnstable;

  /// No description provided for @calibErrInconsistent.
  ///
  /// In en, this message translates to:
  /// **'The two points disagree — redo both measurements'**
  String get calibErrInconsistent;

  /// No description provided for @calibResultAdjust.
  ///
  /// In en, this message translates to:
  /// **'Distances will be corrected by {percent}'**
  String calibResultAdjust(String percent);

  /// No description provided for @calibSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get calibSave;

  /// No description provided for @calibRetry.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get calibRetry;

  /// No description provided for @calibSaved.
  ///
  /// In en, this message translates to:
  /// **'Calibration saved'**
  String get calibSaved;

  /// No description provided for @calibCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current correction: {percent}'**
  String calibCurrent(String percent);

  /// No description provided for @calibReset.
  ///
  /// In en, this message translates to:
  /// **'Remove calibration'**
  String get calibReset;

  /// No description provided for @settingsSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Sensor sensitivity (updates/second)'**
  String get settingsSensitivity;

  /// No description provided for @settingsTestMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode — lane detection (experimental)'**
  String get settingsTestMode;

  /// No description provided for @settingsDevMode.
  ///
  /// In en, this message translates to:
  /// **'Developer mode'**
  String get settingsDevMode;

  /// No description provided for @warnLaneDeparture.
  ///
  /// In en, this message translates to:
  /// **'Lane departure'**
  String get warnLaneDeparture;

  /// No description provided for @settingsAlertSounds.
  ///
  /// In en, this message translates to:
  /// **'Alert sounds'**
  String get settingsAlertSounds;

  /// No description provided for @alertTypeDeparture.
  ///
  /// In en, this message translates to:
  /// **'Lead vehicle moves off'**
  String get alertTypeDeparture;

  /// No description provided for @alertTypeCollision.
  ///
  /// In en, this message translates to:
  /// **'Collision'**
  String get alertTypeCollision;

  /// No description provided for @alertTypeLane.
  ///
  /// In en, this message translates to:
  /// **'Lane departure'**
  String get alertTypeLane;

  /// No description provided for @alertTypeGap.
  ///
  /// In en, this message translates to:
  /// **'Minimum following gap'**
  String get alertTypeGap;

  /// No description provided for @soundVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get soundVoice;

  /// No description provided for @soundBeep.
  ///
  /// In en, this message translates to:
  /// **'Beep'**
  String get soundBeep;

  /// No description provided for @soundOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get soundOff;
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
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
