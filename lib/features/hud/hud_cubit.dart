import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/app_bloc_observer.dart';
import '../../core/adas_channel.dart';
import '../../domain/collision_warning.dart';
import '../../domain/distance_estimator.dart';
import '../../domain/lane_monitor.dart';
import '../../domain/lead_departure.dart';
import '../../domain/models.dart';
import '../../domain/safe_distance.dart';
import '../../domain/solar.dart';
import '../../services/weather_service.dart';
import '../calibration/calibration_cubit.dart';
import 'hud_state.dart';

/// Fuses the native detection stream, GPS, weather and solar time into the
/// single HUD state. Runs at ~10 Hz; significant transitions (alerts,
/// departures, status) are logged as Crashlytics breadcrumbs here — routine
/// distance updates are deliberately not (see AppBlocObserver).
class HudCubit extends Cubit<HudState> {
  HudCubit({WeatherService? weatherService})
      : _weather = weatherService ?? WeatherService(),
        super(const HudState());

  final WeatherService _weather;
  final Geocoding _geocoding = Geocoding();
  final DistanceEstimator _estimator = DistanceEstimator();
  final CollisionMonitor _collision = CollisionMonitor();
  final LeadDepartureDetector _departure = LeadDepartureDetector();
  final LaneMonitor _laneMonitor = LaneMonitor();

  /// Displayed distances refresh at this interval; the safety pipeline and
  /// alerts always run per frame (~10 Hz). Configured from the settings
  /// "sensor sensitivity" slider via [applyDisplaySensitivity].
  Duration _displayInterval = const Duration(seconds: 1);
  DateTime? _lastDisplayAt;

  StreamSubscription<AdasFrame>? _frameSub;
  StreamSubscription<Position>? _posSub;
  Timer? _weatherTimer;
  DateTime? _lastGeocodeAt;
  double? _lastGeocodeLat;
  double? _lastGeocodeLon;

  static const _weatherRefresh = Duration(minutes: 15);
  static const _geocodeMinInterval = Duration(minutes: 2);
  static const _geocodeMinMoveMeters = 1000.0;

  /// Starts native video recording (test-mode "Quay"). Returns false when
  /// no real camera is available.
  Future<bool> startRecording() async {
    final ok = await AdasChannel.startRecording();
    if (ok) {
      crashlyticsLog('HudCubit: recording started');
      emit(state.copyWith(
          isRecording: true, recordingStartedAt: DateTime.now()));
    }
    return ok;
  }

  /// Stops recording and moves the file into the photo library.
  Future<bool> stopRecordingAndSave() async {
    final path = await AdasChannel.stopRecording();
    emit(state.copyWith(isRecording: false, recordingStartedAt: null));
    crashlyticsLog('HudCubit: recording stopped (saved=${path != null})');
    if (path == null) return false;
    try {
      await Gal.putVideo(path);
      await File(path).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [level] 1-10 = displayed updates per second.
  void applyDisplaySensitivity(int level) {
    _displayInterval =
        Duration(milliseconds: (1000 / level.clamp(1, 10)).round());
  }

  Future<void> start() async {
    await reloadCalibration();
    final textureId = await AdasChannel.start();
    if (textureId != null) {
      emit(state.copyWith(textureId: textureId));
    }
    _frameSub = AdasChannel.frames.listen(_onFrame);
    await _initLocation();
    _weatherTimer = Timer.periodic(_weatherRefresh, (_) => _refreshWeather());
  }

  Future<void> _initLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      crashlyticsLog('HudCubit: location permission denied');
      emit(state.copyWith(status: HudStatus.locationDenied));
      return;
    }
    emit(state.copyWith(status: HudStatus.running));
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(_onPosition);
  }

  void _onFrame(AdasFrame frame) {
    // Per-frame focal length from camera intrinsics beats any FOV guess.
    if (frame.fx != null && frame.fx! > 0) {
      _estimator.fPx = frame.fx!;
    }
    final lead = _estimator.pickLead(frame);
    final distance = lead == null ? null : _estimator.estimate(lead);

    // Overlay + alerts see only relevant vehicles (in-lane when a lane is
    // detected, central band otherwise); the dev chip counts everything.
    var rawCars = 0;
    var rawMotos = 0;
    for (final d in frame.detections) {
      if (d.conf < DistanceEstimator.minConfidence) continue;
      if (d.cls == 'motorcycle') {
        rawMotos++;
      } else if (DistanceEstimator.realWidthM.containsKey(d.cls)) {
        rawCars++;
      }
    }
    final vehicles = <TrackedVehicle>[];
    for (final d in _estimator.relevantDetections(frame)) {
      final dist = _estimator.estimate(d);
      if (dist == null) continue;
      vehicles.add(TrackedVehicle(
        cls: d.cls,
        rect: Rect.fromLTWH(d.x, d.y, d.w, d.h),
        distanceM: dist,
        isLead: identical(d, lead),
      ));
    }

    final alert = _collision.update(
      distanceM: distance,
      egoSpeedKmh: state.speedKmh,
      ts: frame.ts,
    );
    final departed = _departure.update(
      egoSpeedKmh: state.speedKmh,
      leadDistanceM: distance,
      ts: frame.ts,
    );

    final laneFired = _laneMonitor.update(
      offset: frame.lane?.offset,
      conf: frame.lane?.conf ?? 0,
      egoSpeedKmh: state.speedKmh,
      ts: frame.ts,
    );

    if (alert != state.alert) {
      crashlyticsLog('HudCubit: alert ${state.alert} -> $alert '
          '(d=${distance?.toStringAsFixed(1)}m v=${state.speedKmh.toStringAsFixed(0)}km/h)');
    }
    if (departed) {
      crashlyticsLog('HudCubit: lead departed');
    }
    if (laneFired) {
      crashlyticsLog('HudCubit: lane departure ${_laneMonitor.status}');
    }

    // Display throttle: safety events always refresh immediately; routine
    // distance updates follow the configured sensitivity.
    final now = frame.ts;
    final mustDisplay = alert != state.alert ||
        departed ||
        laneFired ||
        _laneMonitor.status != state.laneStatus ||
        _lastDisplayAt == null ||
        now.difference(_lastDisplayAt!) >= _displayInterval;
    if (!mustDisplay) return;
    _lastDisplayAt = now;

    emit(state.copyWith(
      mock: frame.mock,
      leadDistanceM: distance,
      vehicles: vehicles,
      frameW: frame.frameW,
      frameH: frame.frameH,
      requiredGapM: SafeDistance.legalMinimumMeters(state.speedKmh),
      alert: alert,
      departureCount: departed ? state.departureCount + 1 : null,
      lane: frame.lane,
      laneDebug: frame.laneDbg == null
          ? null
          : 'L${frame.laneDbg!['l']} R${frame.laneDbg!['r']} '
              '${frame.laneDbg!['gate']}',
      laneStatus: _laneMonitor.status,
      laneEventCount: laneFired ? state.laneEventCount + 1 : null,
      detectedCars: rawCars,
      detectedMotos: rawMotos,
    ));
  }

  /// Test-mode manual speed (0-130 km/h); null returns control to GPS.
  void setSpeedOverride(double? kmh) {
    crashlyticsLog(
        'HudCubit: speed override ${kmh?.toStringAsFixed(0) ?? 'off'}');
    if (kmh == null) {
      emit(state.copyWith(speedOverrideKmh: null));
      return;
    }
    final clamped = kmh.clamp(0.0, 130.0);
    emit(state.copyWith(
      speedOverrideKmh: clamped,
      speedKmh: clamped,
      requiredGapM: SafeDistance.legalMinimumMeters(clamped),
    ));
  }

  void _onPosition(Position pos) {
    final speedKmh = state.speedOverrideKmh ??
        (pos.speed < 0 ? 0.0 : pos.speed * 3.6);
    final isDay = Solar.isDaytime(
      DateTime.now().toUtc(),
      pos.latitude,
      pos.longitude,
    );
    final firstFix = state.lat == null;
    emit(state.copyWith(
      speedKmh: speedKmh,
      lat: pos.latitude,
      lon: pos.longitude,
      isDay: isDay,
    ));
    if (firstFix) {
      _refreshWeather();
    }
    _maybeReverseGeocode(pos);
  }

  /// (Re)loads the user's two-point calibration scale (see
  /// features/calibration). Called on start and after saving a calibration.
  Future<void> reloadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble(CalibrationCubit.prefsKey) ?? 1.0;
    if (scale != _estimator.scale) {
      _estimator.scale = scale;
      crashlyticsLog('HudCubit: calibration scale=$scale');
    }
  }

  Future<void> _refreshWeather() async {
    final lat = state.lat, lon = state.lon;
    if (lat == null || lon == null) return;
    final snapshot = await _weather.fetch(lat, lon);
    if (!isClosed && snapshot != null) {
      emit(state.copyWith(weather: snapshot));
    }
  }

  Future<void> _maybeReverseGeocode(Position pos) async {
    final now = DateTime.now();
    if (_lastGeocodeAt != null &&
        now.difference(_lastGeocodeAt!) < _geocodeMinInterval) {
      return;
    }
    if (_lastGeocodeLat != null && _lastGeocodeLon != null) {
      final moved = Geolocator.distanceBetween(
        _lastGeocodeLat!,
        _lastGeocodeLon!,
        pos.latitude,
        pos.longitude,
      );
      if (moved < _geocodeMinMoveMeters && state.areaName != null) return;
    }
    _lastGeocodeAt = now;
    _lastGeocodeLat = pos.latitude;
    _lastGeocodeLon = pos.longitude;
    try {
      // Needs network on both platforms; last known name is kept when offline.
      final placemarks =
          await _geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isEmpty || isClosed) return;
      final p = placemarks.first;
      final name = [p.subAdministrativeArea, p.administrativeArea]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(', ');
      if (name.isNotEmpty) {
        emit(state.copyWith(areaName: name));
      }
    } catch (_) {/* offline — keep the cached name */}
  }

  @override
  Future<void> close() async {
    if (state.isRecording) {
      await stopRecordingAndSave();
    }
    await _frameSub?.cancel();
    await _posSub?.cancel();
    _weatherTimer?.cancel();
    await AdasChannel.stop();
    return super.close();
  }
}
