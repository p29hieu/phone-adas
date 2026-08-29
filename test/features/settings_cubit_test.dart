import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/features/settings/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults: auto theme, system locale', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = SettingsCubit();
    await cubit.load();
    expect(cubit.state.themePref, ThemePref.auto);
    expect(cubit.state.localePref, LocalePref.system);
    expect(cubit.state.localeOverride, isNull);
  });

  test('theme and locale persist across cubit instances', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = SettingsCubit();
    await cubit.load();
    await cubit.setTheme(ThemePref.dark);
    await cubit.setLocale(LocalePref.vi);

    final restored = SettingsCubit();
    await restored.load();
    expect(restored.state.themePref, ThemePref.dark);
    expect(restored.state.localePref, LocalePref.vi);
    expect(restored.state.localeOverride!.languageCode, 'vi');
  });

  test('auto theme follows daylight', () {
    const s = SettingsState(themePref: ThemePref.auto);
    expect(s.resolveThemeMode(isDay: true), ThemeMode.light);
    expect(s.resolveThemeMode(isDay: false), ThemeMode.dark);
    const dark = SettingsState(themePref: ThemePref.dark);
    expect(dark.resolveThemeMode(isDay: true), ThemeMode.dark);
  });
}
