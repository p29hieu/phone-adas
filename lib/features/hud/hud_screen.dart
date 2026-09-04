import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:gal/gal.dart';

import '../../cookbook/bbox_overlay.dart';
import '../../cookbook/hud_numeral.dart';
import '../../cookbook/pulsing_border.dart';
import '../../cookbook/status_badge.dart';
import '../../domain/collision_warning.dart';
import '../../domain/distance_estimator.dart';
import '../../domain/distance_format.dart';
import '../../l10n/app_localizations.dart';
import '../../services/weather_service.dart';
import '../calibration/calibration_screen.dart';
import '../../core/adas_channel.dart';
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

  // Event bookkeeping so each alert announces only its OWN transitions.
  int _seenDepartures = 0;
  int _seenLaneEvents = 0;
  AdasAlert _seenAlert = AdasAlert.none;
  final Map<AlertKind, DateTime> _lastSoundAt = {};
  static const _soundCooldown = Duration(seconds: 4);

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

  /// Announces one alert kind per its configured sound, rate-limited so a
  /// persisting condition cannot machine-gun the speaker.
  Future<void> _notify(AlertKind kind, String phrase) async {
    final sound = context.read<SettingsCubit>().state.soundFor(kind);
    if (sound == AlertSound.off) return;
    final now = DateTime.now();
    final last = _lastSoundAt[kind];
    if (last != null && now.difference(last) < _soundCooldown) return;
    _lastSoundAt[kind] = now;
    switch (sound) {
      case AlertSound.voice:
        await _speak(phrase);
      case AlertSound.beep:
        await AdasChannel.beep();
      case AlertSound.off:
        break;
    }
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

  Color _alertColor(HudState s) => switch (s.alert) {
        AdasAlert.collision || AdasAlert.collisionCritical => _red,
        AdasAlert.keepDistance => _orange,
        AdasAlert.none => Colors.green.shade500,
      };

  static bool _laneLocked(HudState state) =>
      state.lane != null &&
      state.lane!.conf >= DistanceEstimator.laneMinConf;

  Widget _recordButton(AppLocalizations l10n, HudState state) =>
      _ToolbarButton(
        icon: state.isRecording ? Icons.stop_circle : Icons.videocam,
        iconColor:
            state.isRecording ? const Color(0xFFFF5252) : Colors.white,
        label: state.isRecording
            ? (state.recordingStartedAt == null
                ? l10n.toolbarRecord
                : _fmtElapsed(
                    DateTime.now().difference(state.recordingStartedAt!)))
            : l10n.toolbarRecord,
        onTap: () => _toggleRecording(l10n),
      );

  Widget _photoButton(AppLocalizations l10n) => _ToolbarButton(
        icon: Icons.photo_camera,
        label: l10n.toolbarPhoto,
        onTap: () => _takeScreenshot(l10n),
      );

  Widget _settingsButton(AppLocalizations l10n) => _ToolbarButton(
        icon: Icons.settings,
        label: l10n.toolbarSettings,
        onTap: _openSettings,
      );

  Widget _historyButton(AppLocalizations l10n) => _ToolbarButton(
        icon: Icons.history,
        label: l10n.toolbarHistory,
        onTap: () => _comingSoon(l10n),
      );

  List<Widget> _allButtons(AppLocalizations l10n, HudState state) => [
        _recordButton(l10n, state),
        _photoButton(l10n),
        _settingsButton(l10n),
        _historyButton(l10n),
      ];

  static String _fmtElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleRecording(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.read<SettingsCubit>().state.testMode) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.recTestModeOnly)));
      return;
    }
    final hud = context.read<HudCubit>();
    if (hud.state.isRecording) {
      final saved = await hud.stopRecordingAndSave();
      messenger.showSnackBar(
          SnackBar(content: Text(saved ? l10n.recSaved : l10n.recFailed)));
    } else {
      final started = await hud.startRecording();
      if (!started) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.recNeedCamera)));
      }
    }
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
    final screen = MediaQuery.sizeOf(context);
    final isLandscape = screen.width > screen.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<HudCubit, HudState>(
        listenWhen: (prev, next) =>
            prev.alert != next.alert ||
            prev.departureCount != next.departureCount ||
            prev.laneEventCount != next.laneEventCount,
        listener: (context, state) {
          if (state.departureCount > _seenDepartures) {
            _seenDepartures = state.departureCount;
            _notify(AlertKind.departure, l10n.warnLeadDeparted);
          }
          if (state.laneEventCount > _seenLaneEvents) {
            _seenLaneEvents = state.laneEventCount;
            final settings = context.read<SettingsCubit>().state;
            if (settings.testMode && settings.showLane) {
              _notify(AlertKind.lane, l10n.warnLaneDeparture);
            }
          }
          if (state.alert != _seenAlert) {
            _seenAlert = state.alert;
            switch (state.alert) {
              case AdasAlert.collision:
              case AdasAlert.collisionCritical:
                _notify(AlertKind.collision, l10n.warnCollision);
              case AdasAlert.keepDistance:
                _notify(AlertKind.gap, l10n.warnKeepDistance);
              case AdasAlert.none:
                break;
            }
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
                    context.watch<SettingsCubit>().state.showLane &&
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
                  // With a confident lane lock, only the lead vehicle is
                  // annotated — the dedicated panel below carries the
                  // number; without a lane, all relevant vehicles show.
                  items: [
                    for (final v in state.vehicles)
                      if (!_laneLocked(state) || v.isLead)
                        _bubbleFor(v, state),
                  ],
                ),
                PulsingBorder(
                  active: state.alert == AdasAlert.collision ||
                      state.alert == AdasAlert.collisionCritical,
                  color: const Color(0xFFE53935),
                  period: const Duration(seconds: 2),
                ),
                if (context.watch<SettingsCubit>().state.testMode &&
                    context.watch<SettingsCubit>().state.manualSpeed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SafeArea(
                      child: _SpeedOverridePanel(state: state),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: _InfoCard(
                                  state: state, l10n: l10n, time: _time),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (state.isRecording) ...[
                                  StatusBadge(
                                    'REC ${state.recordingStartedAt == null ? '' : _fmtElapsed(DateTime.now().difference(state.recordingStartedAt!))}',
                                    background: const Color(0xFFC62828),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (state.mock) ...[
                                  StatusBadge(
                                    l10n.mockModeBadge,
                                    background: Colors.orange.shade800,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (state.weather != null) ...[
                                  _WeatherChip(
                                    icon: _weatherIcon(state.weather!.kind),
                                    label:
                                        '${state.weather!.tempC.round()}°C'
                                        '${state.weather!.isStale ? ' *' : ''}',
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (context
                                    .watch<SettingsCubit>()
                                    .state
                                    .devMode)
                                  _DevCountsChip(
                                    cars: state.detectedCars,
                                    motos: state.detectedMotos,
                                    laneDebug: state.laneDebug,
                                    versionLabel: state.versionLabel,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: _LeadDistancePanel(
                            state: state,
                            l10n: l10n,
                            laneLocked: _laneLocked(state),
                            color: _alertColor(state),
                          ),
                        ),
                        if (!isLandscape) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: _ButtonPill(
                              vertical: false,
                              children: _allButtons(l10n, state),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isLandscape) ...[
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: _ButtonPill(
                          vertical: true,
                          children: [
                            _recordButton(l10n, state),
                            _photoButton(l10n),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: _ButtonPill(
                          vertical: true,
                          children: [
                            _settingsButton(l10n),
                            _historyButton(l10n),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
    const labelStyle = TextStyle(color: Color(0xFF555555), fontSize: 11);
    const valueStyle = TextStyle(
      color: Color(0xFF1A1A1A),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Speed:', style: labelStyle),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      HudNumeral(
                        state.speedKmh.toStringAsFixed(0),
                        size: 28,
                        color: const Color(0xFF1A1A1A),
                      ),
                      const SizedBox(width: 3),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text('km/h', style: valueStyle),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0x33000000),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
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
                fontSize: 13,
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
                    fontSize: 12,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1A1A1A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonPill extends StatelessWidget {
  const _ButtonPill({required this.vertical, required this.children});

  final bool vertical;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: content,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

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
            Icon(icon, color: iconColor, size: 24),
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

/// Test-mode vertical slider simulating the ego speed (0-130 km/h) so the
/// alert pipeline can be exercised against recorded videos on a screen.
/// Dedicated, glanceable readout of the lead-vehicle distance. Turns
/// orange/red with the alert level; shows a lane icon while the vehicle
/// filter is locked onto the detected ego lane.
class _LeadDistancePanel extends StatelessWidget {
  const _LeadDistancePanel({
    required this.state,
    required this.l10n,
    required this.laneLocked,
    required this.color,
  });

  final HudState state;
  final AppLocalizations l10n;
  final bool laneLocked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final distance = state.leadDistanceM;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (laneLocked)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: Icon(Icons.add_road, size: 18, color: color),
            ),
          if (distance == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.hudNoLeadVehicle,
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            )
          else ...[
            HudNumeral(formatDistanceM(distance), size: 44, color: color),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text('m',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ),
            if (state.requiredGapM > 0) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  l10n.hudRequiredGap(state.requiredGapM.round()),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SpeedOverridePanel extends StatelessWidget {
  const _SpeedOverridePanel({required this.state});

  final HudState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HudCubit>();
    final overriding = state.speedOverrideKmh != null;
    return Container(
      margin: const EdgeInsets.only(left: 2),
      padding: const EdgeInsets.symmetric(vertical: 4),
      width: 40,
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(state.speedOverrideKmh ?? state.speedKmh).round()}',
            style: TextStyle(
              color: overriding ? Colors.amber : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(
            height: 120,
            width: 32,
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: (state.speedOverrideKmh ?? state.speedKmh)
                      .clamp(0.0, 130.0),
                  min: 0,
                  max: 130,
                  activeColor: overriding ? Colors.amber : Colors.white38,
                  onChanged: (v) => cubit.setSpeedOverride(v),
                ),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 22),
              foregroundColor: overriding ? Colors.white : Colors.white38,
            ),
            onPressed: overriding ? () => cubit.setSpeedOverride(null) : null,
            child: const Text('GPS', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _DevCountsChip extends StatelessWidget {
  const _DevCountsChip({
    required this.cars,
    required this.motos,
    this.laneDebug,
    this.versionLabel,
  });

  final int cars;
  final int motos;
  final String? laneDebug;
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    Widget row(IconData icon, int count) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 5),
            Text('$count', style: style),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC1565C0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.directions_car, cars),
          const SizedBox(height: 3),
          row(Icons.two_wheeler, motos),
          if (laneDebug != null) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  laneDebug!,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ],
          if (versionLabel != null) ...[
            const SizedBox(height: 3),
            Text(
              versionLabel!,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertSoundRow extends StatelessWidget {
  const _AlertSoundRow({required this.kind, required this.label});

  final AlertKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsCubit>().state;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          SegmentedButton<AlertSound>(
            segments: [
              ButtonSegment(
                value: AlertSound.voice,
                icon: const Icon(Icons.record_voice_over, size: 16),
                label: Text(l10n.soundVoice),
              ),
              ButtonSegment(
                value: AlertSound.beep,
                icon: const Icon(Icons.notifications_active, size: 16),
                label: Text(l10n.soundBeep),
              ),
              ButtonSegment(
                value: AlertSound.off,
                icon: const Icon(Icons.notifications_off, size: 16),
                label: Text(l10n.soundOff),
              ),
            ],
            selected: {settings.soundFor(kind)},
            onSelectionChanged: (sel) =>
                context.read<SettingsCubit>().setAlertSound(kind, sel.first),
          ),
        ],
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
              Text(l10n.settingsAlertSounds,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _AlertSoundRow(
                  kind: AlertKind.departure,
                  label: l10n.alertTypeDeparture),
              _AlertSoundRow(
                  kind: AlertKind.collision, label: l10n.alertTypeCollision),
              _AlertSoundRow(kind: AlertKind.lane, label: l10n.alertTypeLane),
              _AlertSoundRow(kind: AlertKind.gap, label: l10n.alertTypeGap),
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
              if (settings.testMode) ...[
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 24),
                  dense: true,
                  value: settings.showLane,
                  title: Text(l10n.settingsShowLane),
                  onChanged: cubit.setShowLane,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 24),
                  dense: true,
                  value: settings.manualSpeed,
                  title: Text(l10n.settingsManualSpeed),
                  onChanged: cubit.setManualSpeed,
                ),
              ],
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
