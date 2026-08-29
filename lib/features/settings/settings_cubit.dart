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
    this.loaded = false,
  });

  final ThemePref themePref;
  final LocalePref localePref;
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
    bool? loaded,
  }) =>
      SettingsState(
        themePref: themePref ?? this.themePref,
        localePref: localePref ?? this.localePref,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [themePref, localePref, loaded];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _kTheme = 'settings_theme_v1';
  static const _kLocale = 'settings_locale_v1';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    emit(SettingsState(
      themePref: ThemePref.values[prefs.getInt(_kTheme) ?? 0],
      localePref: LocalePref.values[prefs.getInt(_kLocale) ?? 0],
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
}
