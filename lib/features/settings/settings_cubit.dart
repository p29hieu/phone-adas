import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePref { auto, light, dark }

enum LocalePref { system, vi, en }

/// How one alert type is announced.
enum AlertSound { voice, beep, off }

/// The four announceable alert types.
enum AlertKind { departure, collision, lane, gap }

/// HUD rendering mode: live camera + AR overlay, or the Tesla-style scene.
enum ViewMode { camera, scene }

class SettingsState extends Equatable {
  const SettingsState({
    this.themePref = ThemePref.auto,
    this.localePref = LocalePref.system,
    this.sensitivity = 1,
    this.devMode = false,
    this.testMode = false,
    this.soundDeparture = AlertSound.voice,
    this.soundCollision = AlertSound.voice,
    this.soundLane = AlertSound.voice,
    this.soundGap = AlertSound.voice,
    this.showLane = true,
    this.manualSpeed = true,
    this.hoodOffsetM = 0.7,
    this.viewMode = ViewMode.camera,
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

  final AlertSound soundDeparture;
  final AlertSound soundCollision;
  final AlertSound soundLane;
  final AlertSound soundGap;

  /// Test-mode sub-feature: lane overlay + lane-departure warning.
  final bool showLane;

  /// Test-mode sub-feature: manual speed slider.
  final bool manualSpeed;

  /// Phone-to-front-bumper distance (m), subtracted from every measured
  /// distance so readouts and legal gaps are bumper-to-bumper.
  final double hoodOffsetM;
  final ViewMode viewMode;
  final bool loaded;

  AlertSound soundFor(AlertKind kind) => switch (kind) {
        AlertKind.departure => soundDeparture,
        AlertKind.collision => soundCollision,
        AlertKind.lane => soundLane,
        AlertKind.gap => soundGap,
      };

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
    AlertSound? soundDeparture,
    AlertSound? soundCollision,
    AlertSound? soundLane,
    AlertSound? soundGap,
    bool? showLane,
    bool? manualSpeed,
    double? hoodOffsetM,
    ViewMode? viewMode,
    bool? loaded,
  }) =>
      SettingsState(
        themePref: themePref ?? this.themePref,
        localePref: localePref ?? this.localePref,
        sensitivity: sensitivity ?? this.sensitivity,
        devMode: devMode ?? this.devMode,
        testMode: testMode ?? this.testMode,
        soundDeparture: soundDeparture ?? this.soundDeparture,
        soundCollision: soundCollision ?? this.soundCollision,
        soundLane: soundLane ?? this.soundLane,
        soundGap: soundGap ?? this.soundGap,
        showLane: showLane ?? this.showLane,
        manualSpeed: manualSpeed ?? this.manualSpeed,
        hoodOffsetM: hoodOffsetM ?? this.hoodOffsetM,
        viewMode: viewMode ?? this.viewMode,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [
        themePref,
        localePref,
        sensitivity,
        devMode,
        testMode,
        soundDeparture,
        soundCollision,
        soundLane,
        soundGap,
        showLane,
        manualSpeed,
        hoodOffsetM,
        viewMode,
        loaded,
      ];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _kTheme = 'settings_theme_v1';
  static const _kLocale = 'settings_locale_v1';
  static const _kSensitivity = 'settings_sensitivity_v1';
  static const _kDevMode = 'settings_dev_mode_v1';
  static const _kTestMode = 'settings_test_mode_v1';
  static const _kSoundPrefix = 'settings_alert_sound_v1_';
  static const _kShowLane = 'settings_show_lane_v1';
  static const _kManualSpeed = 'settings_manual_speed_v1';
  static const _kHoodOffset = 'settings_hood_offset_v1';
  static const _kViewMode = 'settings_view_mode_v1';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    emit(SettingsState(
      themePref: ThemePref.values[prefs.getInt(_kTheme) ?? 0],
      localePref: LocalePref.values[prefs.getInt(_kLocale) ?? 0],
      sensitivity: (prefs.getInt(_kSensitivity) ?? 1).clamp(1, 10),
      devMode: prefs.getBool(_kDevMode) ?? false,
      testMode: prefs.getBool(_kTestMode) ?? false,
      soundDeparture: _loadSound(prefs, AlertKind.departure),
      soundCollision: _loadSound(prefs, AlertKind.collision),
      soundLane: _loadSound(prefs, AlertKind.lane),
      soundGap: _loadSound(prefs, AlertKind.gap),
      showLane: prefs.getBool(_kShowLane) ?? true,
      manualSpeed: prefs.getBool(_kManualSpeed) ?? true,
      hoodOffsetM: (prefs.getDouble(_kHoodOffset) ?? 0.7).clamp(0.0, 3.0),
      viewMode: ViewMode
          .values[(prefs.getInt(_kViewMode) ?? 0).clamp(0, 1)],
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

  static AlertSound _loadSound(SharedPreferences prefs, AlertKind kind) {
    final i = prefs.getInt('$_kSoundPrefix${kind.name}') ?? 0;
    return AlertSound.values[i.clamp(0, AlertSound.values.length - 1)];
  }

  Future<void> setAlertSound(AlertKind kind, AlertSound sound) async {
    emit(switch (kind) {
      AlertKind.departure => state.copyWith(soundDeparture: sound),
      AlertKind.collision => state.copyWith(soundCollision: sound),
      AlertKind.lane => state.copyWith(soundLane: sound),
      AlertKind.gap => state.copyWith(soundGap: sound),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kSoundPrefix${kind.name}', sound.index);
  }

  Future<void> setHoodOffset(double meters) async {
    final clamped = meters.clamp(0.0, 3.0);
    emit(state.copyWith(hoodOffsetM: clamped));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kHoodOffset, clamped);
  }

  Future<void> setViewMode(ViewMode mode) async {
    emit(state.copyWith(viewMode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kViewMode, mode.index);
  }

  Future<void> setShowLane(bool on) async {
    emit(state.copyWith(showLane: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowLane, on);
  }

  Future<void> setManualSpeed(bool on) async {
    emit(state.copyWith(manualSpeed: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kManualSpeed, on);
  }

  Future<void> setTestMode(bool on) async {
    emit(state.copyWith(testMode: on));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTestMode, on);
  }
}
