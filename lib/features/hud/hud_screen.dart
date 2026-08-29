import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gal/gal.dart';

import '../../domain/collision_warning.dart';
import '../../l10n/app_localizations.dart';
import '../../services/weather_service.dart';
import '../settings/settings_cubit.dart';
import 'hud_cubit.dart';
import 'hud_state.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final FlutterTts _tts = FlutterTts();

  Future<void> _speak(String text) async {
    final locale = Localizations.localeOf(context);
    await _tts.setLanguage(locale.languageCode == 'vi' ? 'vi-VN' : 'en-US');
    await _tts.speak(text);
  }

  Future<void> _takeScreenshot(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _captureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Gal.putImageBytes(
        bytes!.buffer.asUint8List(),
        name: 'phone_adas_${DateTime.now().millisecondsSinceEpoch}',
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.screenshotSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.screenshotFailed)));
    }
  }

  Color _distanceColor(HudState s, ColorScheme scheme) {
    switch (s.alert) {
      case AdasAlert.collision:
      case AdasAlert.collisionCritical:
        return Colors.red;
      case AdasAlert.keepDistance:
        return Colors.orange;
      case AdasAlert.none:
        return Colors.green.shade600;
    }
  }

  IconData _weatherIcon(WeatherKind kind) => switch (kind) {
        WeatherKind.clear => Icons.wb_sunny,
        WeatherKind.partlyCloudy => Icons.wb_cloudy,
        WeatherKind.cloudy => Icons.cloud,
        WeatherKind.fog => Icons.dehaze,
        WeatherKind.drizzle => Icons.grain,
        WeatherKind.rain => Icons.water_drop,
        WeatherKind.snow => Icons.ac_unit,
        WeatherKind.thunderstorm => Icons.flash_on,
      };

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<SettingsCubit>(),
        child: const _SettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<HudCubit, HudState>(
          listenWhen: (prev, next) =>
              prev.alert != next.alert ||
              prev.departureCount != next.departureCount,
          listener: (context, state) {
            if (state.departureCount > 0) {
              _speak(l10n.warnLeadDeparted);
            }
            switch (state.alert) {
              case AdasAlert.collision:
              case AdasAlert.collisionCritical:
                _speak(l10n.warnCollision);
              case AdasAlert.keepDistance:
                _speak(l10n.warnKeepDistance);
              case AdasAlert.none:
                break;
            }
          },
          builder: (context, state) {
            return RepaintBoundary(
              key: _captureKey,
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    _TopBar(
                      state: state,
                      l10n: l10n,
                      weatherIcon: _weatherIcon,
                      onSettings: _openSettings,
                    ),
                    Expanded(
                      child: _DistancePanel(
                        state: state,
                        l10n: l10n,
                        color: _distanceColor(state, scheme),
                      ),
                    ),
                    _BottomBar(
                      state: state,
                      l10n: l10n,
                      onScreenshot: () => _takeScreenshot(l10n),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.l10n,
    required this.weatherIcon,
    required this.onSettings,
  });

  final HudState state;
  final AppLocalizations l10n;
  final IconData Function(WeatherKind) weatherIcon;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall!.copyWith(
      color: textTheme.bodySmall!.color!.withValues(alpha: 0.6),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.areaName ?? l10n.hudLocating,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (state.lat != null && state.lon != null)
                  Text(
                    '${state.lat!.toStringAsFixed(5)}, '
                    '${state.lon!.toStringAsFixed(5)}',
                    style: muted,
                  ),
              ],
            ),
          ),
          if (state.mock)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.mockModeBadge,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          if (state.weather != null) ...[
            Icon(weatherIcon(state.weather!.kind), size: 22),
            const SizedBox(width: 4),
            Text(
              '${state.weather!.tempC.round()}°C'
              '${state.weather!.isStale ? ' *' : ''}',
              style: textTheme.titleMedium,
            ),
          ],
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.settings), onPressed: onSettings),
        ],
      ),
    );
  }
}

class _DistancePanel extends StatelessWidget {
  const _DistancePanel({
    required this.state,
    required this.l10n,
    required this.color,
  });

  final HudState state;
  final AppLocalizations l10n;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final distance = state.leadDistanceM;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (distance == null)
            Text(
              l10n.hudNoLeadVehicle,
              style: Theme.of(context).textTheme.headlineSmall,
            )
          else ...[
            Text(
              distance.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 120,
                height: 1,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            Text(
              'm  ·  ${l10n.hudDistanceToLead}'
              '${state.requiredGapM > 0 ? '  ·  ${l10n.hudRequiredGap(state.requiredGapM.round())}' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.l10n,
    required this.onScreenshot,
  });

  final HudState state;
  final AppLocalizations l10n;
  final VoidCallback onScreenshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            state.speedKmh.toStringAsFixed(0),
            style: textTheme.displayMedium!.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.hudSpeedUnit, style: textTheme.titleMedium),
          ),
          const Spacer(),
          IconButton.filledTonal(
            iconSize: 28,
            icon: const Icon(Icons.photo_camera),
            onPressed: onScreenshot,
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.settingsTheme,
                  style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<ThemePref>(
                groupValue: settings.themePref,
                onChanged: (v) => cubit.setTheme(v!),
                child: Column(
                  children: [
                    RadioListTile<ThemePref>(
                      value: ThemePref.auto,
                      title: Text(l10n.settingsThemeAuto),
                    ),
                    RadioListTile<ThemePref>(
                      value: ThemePref.light,
                      title: Text(l10n.settingsThemeLight),
                    ),
                    RadioListTile<ThemePref>(
                      value: ThemePref.dark,
                      title: Text(l10n.settingsThemeDark),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Text(l10n.settingsLanguage,
                  style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<LocalePref>(
                groupValue: settings.localePref,
                onChanged: (v) => cubit.setLocale(v!),
                child: Column(
                  children: [
                    RadioListTile<LocalePref>(
                      value: LocalePref.system,
                      title: Text(l10n.settingsLanguageSystem),
                    ),
                    RadioListTile<LocalePref>(
                      value: LocalePref.vi,
                      title: const Text('Tiếng Việt'),
                    ),
                    RadioListTile<LocalePref>(
                      value: LocalePref.en,
                      title: const Text('English'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
