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

  @override
  String get toolbarRecord => 'Record';

  @override
  String get toolbarPhoto => 'Photo';

  @override
  String get toolbarSettings => 'Settings';

  @override
  String get toolbarHistory => 'History';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get hudCameraPlaceholder =>
      'Live camera arrives in phase 2 — mock data for now';

  @override
  String get settingsCalibration => 'Calibrate distance';

  @override
  String get calibIntro =>
      'Mount the phone firmly on its holder first. Then aim the camera at a parked car straight ahead. You will measure twice: at 10 m and at 30 m (lane dashes are 3 m long with 6 m gaps — handy as a ruler).';

  @override
  String get calibStart => 'Start';

  @override
  String calibPointPrompt(int index, int meters) {
    return 'Point $index/2 — target car at $meters m';
  }

  @override
  String calibDetected(String meters) {
    return 'Detected: $meters m';
  }

  @override
  String get calibNoVehicle => 'No vehicle detected — aim at the car';

  @override
  String get calibSample => 'Sample (3 s)';

  @override
  String get calibSampling => 'Hold still — sampling…';

  @override
  String get calibErrTooFew => 'Not enough stable detections — try again';

  @override
  String get calibErrUnstable =>
      'Readings unstable — keep the phone and target still';

  @override
  String get calibErrInconsistent =>
      'The two points disagree — redo both measurements';

  @override
  String calibResultAdjust(String percent) {
    return 'Distances will be corrected by $percent';
  }

  @override
  String get calibSave => 'Save';

  @override
  String get calibRetry => 'Redo';

  @override
  String get calibSaved => 'Calibration saved';

  @override
  String calibCurrent(String percent) {
    return 'Current correction: $percent';
  }

  @override
  String get calibReset => 'Remove calibration';
}
