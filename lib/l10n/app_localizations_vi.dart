// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Phone ADAS';

  @override
  String get hudSpeedUnit => 'km/h';

  @override
  String get hudDistanceToLead => 'Khoảng cách';

  @override
  String hudRequiredGap(int meters) {
    return 'cần $meters m';
  }

  @override
  String get hudNoLeadVehicle => 'Không có xe phía trước';

  @override
  String get warnKeepDistance => 'Giữ khoảng cách';

  @override
  String get warnCollision => 'Phanh! Nguy cơ va chạm';

  @override
  String get warnLeadDeparted => 'Xe phía trước đã di chuyển';

  @override
  String get hudOffline => 'Ngoại tuyến';

  @override
  String get hudWeatherUnavailable => 'Không có dữ liệu thời tiết';

  @override
  String get hudLocating => 'Đang định vị…';

  @override
  String get screenshotSaved => 'Đã lưu ảnh chụp màn hình';

  @override
  String get screenshotFailed => 'Không lưu được ảnh chụp màn hình';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsTheme => 'Giao diện';

  @override
  String get settingsThemeAuto => 'Tự động (ngày/đêm theo mặt trời)';

  @override
  String get settingsThemeLight => 'Sáng';

  @override
  String get settingsThemeDark => 'Tối';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsLanguageSystem => 'Theo hệ thống';

  @override
  String get camPermissionNeeded => 'Cần quyền camera để đo khoảng cách';

  @override
  String get locPermissionNeeded =>
      'Cần quyền vị trí để hiển thị tốc độ và thời tiết';

  @override
  String get mockModeBadge => 'DỮ LIỆU GIẢ LẬP';

  @override
  String get toolbarRecord => 'Quay';

  @override
  String get toolbarPhoto => 'Chụp';

  @override
  String get toolbarSettings => 'Cài đặt';

  @override
  String get toolbarHistory => 'Lịch sử';

  @override
  String get comingSoon => 'Sắp có';

  @override
  String get hudCameraPlaceholder =>
      'Camera thật sẽ có ở giai đoạn 2 — đang chạy dữ liệu giả lập';
}
