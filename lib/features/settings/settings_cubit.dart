import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePref { auto, light, dark }

enum LocalePref { system, vi, en }

class SettingsState extends Equatable {
  const SettingsState({
    this.themePref = ThemePref.auto,
    this.localePref = LocalePref.system,
    this.sensitivity = 1,
    this.devMode = false,
    this.testMode = false,
    this.loaded = false,
  });

  final ThemePref themePref;
  final LocalePref localePref;

  /// HUD refresh rate for displayed distances, in updates per second
  /// (1-10). Alerts always update instantly regardless of this value.
  final int sensitivity;

  /// Developer overlay: live detection counts per vehicle group.
  final bool devMode;

  /// Experimental features: lane visualization + lane-departure warning.
  final bool testMode;
  final bool loaded;

  /// Resolves the Material theme mode. `auto` follows real daylight at the
  /// vehicle position (domain/solar.dart), not fixed clock hours.
  ThemeMode resolveThemeMode({required bool isDay}) => switch (themePref) {
        ThemePref.auto => isDay ? ThemeMode.light : ThemeMode.dark,
        ThemePref.light => ThemeMode.light,
        ThemePref.dark => ThemeMode.dark,
      };

  Locale? get localeOverride => switch (localePref) {
        LocalePref.system => null,
        LocalePref.vi => const Locale('vi'),
        LocalePref.en => const Locale('en'),
      };

  SettingsState copyWith({
    ThemePref? themePref,
    LocalePref? localePref,
    int? sensitivity,
    bool? devMode,
    bool? testMode,
    bool? loaded,
  }) =>
      SettingsState(
        themePref: themePref ?? this.themePref,
        localePref: localePref ?? this.localePref,
        sensitivity: sensitivity ?? this.sensitivity,
        devMode: devMode ?? this.devMode,
        testMode: testMode ?? this.testMode,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props =>
      [themePref, localePref, sensitivity, devMode, testMode, loaded];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _kTheme = 'settings_theme_v1';
  static const _kLocale = 'settings_locale_v1';
  static const _kSensitivity = 'settings_sensitivity_v1';
  static const _kDevMode = 'settings_dev_mode_v1';
  static const _kTestMode = 'settings_test_mode_v1';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    emit(SettingsState(
      themePref: ThemePref.values[prefs.getInt(_kTheme) ?? 0],
      localePref: LocalePref.values[prefs.getInt(_kLocale) ?? 0],
      sensitivity: (prefs.getInt(_kSensitivity) ?? 1).clamp(1, 10),
      devMode: prefs.getBool(_kDevMode) ?? false,
      testMode: prefs.getBool(_kTestMode) ?? false,
      loaded: true,
    ));
  }

  Future<void> setTheme(ThemePref pref) async {
    emit(state.copyWith(themePref: pref));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTheme, pref.index);
  }

  Future<void> setLocale(LocalePref pref) async {
    emit(state.copyWith(localePref: pref));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLocale, pref.index);
  }

  Future<void> setSensitivity(int value) async {
    final clamped = value.clamp(1, 10);
    emit(state.copyWith(sensitivity: clamped));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSensitivity, clamped);
  }

  Future<void> setDevMode(bool on) async {
    emit(state.copyWith(devMode: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDevMode, on);
  }

  Future<void> setTestMode(bool on) async {
    emit(state.copyWith(testMode: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTestMode, on);
  }
}
