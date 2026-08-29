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
