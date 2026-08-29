import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gal/gal.dart';

import '../../cookbook/bbox_overlay.dart';
import '../../cookbook/hud_numeral.dart';
import '../../cookbook/status_badge.dart';
import '../../domain/collision_warning.dart';
import '../../domain/distance_format.dart';
import '../../l10n/app_localizations.dart';
import '../../services/weather_service.dart';
import '../calibration/calibration_screen.dart';
import 'lane_overlay.dart';
import '../settings/settings_cubit.dart';
import 'hud_cubit.dart';
import 'hud_state.dart';

/// Main ADAS screen: camera preview (native texture — phase 2) with an
/// AR overlay of per-vehicle distance bubbles, a speed/GPS info card and a
/// bottom toolbar, per the product mockup.
class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final FlutterTts _tts = FlutterTts();
  late final Timer _clock;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _time = _formatTime(DateTime.now());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _time = _formatTime(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

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

  void _comingSoon(AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<SettingsCubit>(),
        child: _SettingsSheet(onCalibrate: () {
          Navigator.pop(sheetContext);
          _openCalibration();
        }),
      ),
    );
  }

  Future<void> _openCalibration() async {
    final hudCubit = context.read<HudCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CalibrationScreen(textureId: hudCubit.state.textureId),
      ),
    );
    if (saved == true) {
      await hudCubit.reloadCalibration();
    }
  }

  static const _paleWhite = Color(0xF2FFFFFF);
  static const _paleAmber = Color(0xFFFFE9A8);
  static const _orange = Color(0xFFFFB74D);
  static const _red = Color(0xFFE53935);

  BBoxItem _bubbleFor(TrackedVehicle v, HudState s) {
    Color color = _paleWhite;
    Color text = const Color(0xFF1A1A1A);
    var emphasized = false;
    if (v.isLead) {
      emphasized = true;
      switch (s.alert) {
        case AdasAlert.collision:
        case AdasAlert.collisionCritical:
          color = _red;
          text = Colors.white;
        case AdasAlert.keepDistance:
          color = _orange;
        case AdasAlert.none:
          if (v.distanceM < 10) color = _paleAmber;
      }
    } else if (v.distanceM < 10) {
      color = _paleAmber;
    }
    return BBoxItem(
      rect: v.rect,
      label: '${formatDistanceM(v.distanceM)} m',
      color: color,
      textColor: text,
      emphasized: emphasized,
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<HudCubit, HudState>(
        listenWhen: (prev, next) =>
            prev.alert != next.alert ||
            prev.departureCount != next.departureCount ||
            prev.laneEventCount != next.laneEventCount,
        listener: (context, state) {
          if (state.departureCount > 0) {
            _speak(l10n.warnLeadDeparted);
          }
          if (state.laneEventCount > 0 &&
              context.read<SettingsCubit>().state.testMode) {
            _speak(l10n.warnLaneDeparture);
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Live camera preview (iOS phase-2 core); cover-fit matches
                // the BBoxOverlay coordinate mapping exactly.
                if (state.textureId != null)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: state.frameW.toDouble(),
                        height: state.frameH.toDouble(),
                        child: Texture(textureId: state.textureId!),
                      ),
                    ),
                  )
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF20242B), Color(0xFF0D0F12)],
                      ),
                    ),
                  ),
                if (state.textureId == null)
                  Align(
                  alignment: const Alignment(0, 0.55),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined,
                          size: 40, color: Colors.white24),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          l10n.hudCameraPlaceholder,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                if (context.watch<SettingsCubit>().state.testMode &&
                    state.lane != null)
                  LaneOverlay(
                    lane: state.lane!,
                    frameSize:
                        Size(state.frameW.toDouble(), state.frameH.toDouble()),
                    status: state.laneStatus,
                  ),
                BBoxOverlay(
                  frameSize:
                      Size(state.frameW.toDouble(), state.frameH.toDouble()),
                  items: [
                    for (final v in state.vehicles) _bubbleFor(v, state),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            _InfoCard(state: state, l10n: l10n, time: _time),
                            if (state.mock)
                              StatusBadge(
                                l10n.mockModeBadge,
                                background: Colors.orange.shade800,
                              ),
                            if (state.weather != null)
                              _WeatherChip(
                                icon: _weatherIcon(state.weather!.kind),
                                label:
                                    '${state.weather!.tempC.round()}°C'
                                    '${state.weather!.isStale ? ' *' : ''}',
                              ),
                            if (context.watch<SettingsCubit>().state.devMode)
                              StatusBadge(
                                l10n.devCounts(
                                  state.vehicles
                                      .where((v) => v.cls != 'motorcycle')
                                      .length,
                                  state.vehicles
                                      .where((v) => v.cls == 'motorcycle')
                                      .length,
                                ),
                                background: const Color(0xCC1565C0),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: _Toolbar(
                            l10n: l10n,
                            onRecord: () => _comingSoon(l10n),
                            onPhoto: () => _takeScreenshot(l10n),
                            onSettings: _openSettings,
                            onHistory: () => _comingSoon(l10n),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.state, required this.l10n, required this.time});

  final HudState state;
  final AppLocalizations l10n;
  final String time;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(color: Color(0xFF555555), fontSize: 13);
    const valueStyle = TextStyle(
      color: Color(0xFF1A1A1A),
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Speed:', style: labelStyle),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      HudNumeral(
                        state.speedKmh.toStringAsFixed(0),
                        size: 34,
                        color: const Color(0xFF1A1A1A),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(l10n.hudSpeedUnit, style: valueStyle),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: const Color(0x33000000),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GPS:', style: labelStyle),
                  if (state.lat != null && state.lon != null) ...[
                    Text(
                      '${state.lat!.abs().toStringAsFixed(4)}° '
                      '${state.lat! >= 0 ? 'N' : 'S'}',
                      style: valueStyle,
                    ),
                    Text(
                      '${state.lon!.abs().toStringAsFixed(4)}° '
                      '${state.lon! >= 0 ? 'E' : 'W'}',
                      style: valueStyle,
                    ),
                  ] else
                    Text(l10n.hudLocating, style: valueStyle),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
            if (state.areaName != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  state.areaName!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.l10n,
    required this.onRecord,
    required this.onPhoto,
    required this.onSettings,
    required this.onHistory,
  });

  final AppLocalizations l10n;
  final VoidCallback onRecord;
  final VoidCallback onPhoto;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarButton(
            icon: Icons.videocam,
            label: l10n.toolbarRecord,
            onTap: onRecord,
          ),
          _ToolbarButton(
            icon: Icons.photo_camera,
            label: l10n.toolbarPhoto,
            onTap: onPhoto,
          ),
          _ToolbarButton(
            icon: Icons.settings,
            label: l10n.toolbarSettings,
            onTap: onSettings,
          ),
          _ToolbarButton(
            icon: Icons.history,
            label: l10n.toolbarHistory,
            onTap: onHistory,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.onCalibrate});

  final VoidCallback onCalibrate;

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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.straighten),
                title: Text(l10n.settingsCalibration),
                trailing: const Icon(Icons.chevron_right),
                onTap: onCalibrate,
              ),
              const Divider(),
              Text(l10n.settingsSensitivity,
                  style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.sensitivity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${settings.sensitivity}',
                      onChanged: (v) => cubit.setSensitivity(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('${settings.sensitivity}',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.testMode,
                title: Text(l10n.settingsTestMode),
                onChanged: cubit.setTestMode,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.devMode,
                title: Text(l10n.settingsDevMode),
                onChanged: cubit.setDevMode,
              ),
              const Divider(),
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
