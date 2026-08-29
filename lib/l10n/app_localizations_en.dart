// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Phone ADAS';

  @override
  String get hudSpeedUnit => 'km/h';

  @override
  String get hudDistanceToLead => 'Distance';

  @override
  String hudRequiredGap(int meters) {
    return 'required $meters m';
  }

  @override
  String get hudNoLeadVehicle => 'No vehicle ahead';

  @override
  String get warnKeepDistance => 'Keep your distance';

  @override
  String get warnCollision => 'Brake! Collision risk';

  @override
  String get warnLeadDeparted => 'Vehicle ahead is moving';

  @override
  String get hudOffline => 'Offline';

  @override
  String get hudWeatherUnavailable => 'Weather unavailable';

  @override
  String get hudLocating => 'Locating…';

  @override
  String get screenshotSaved => 'Screenshot saved';

  @override
  String get screenshotFailed => 'Could not save screenshot';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeAuto => 'Auto (day/night by sun)';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get camPermissionNeeded =>
      'Camera permission is required for distance measurement';

  @override
  String get locPermissionNeeded =>
      'Location permission is required for speed and weather';

  @override
  String get mockModeBadge => 'MOCK DATA';
}
