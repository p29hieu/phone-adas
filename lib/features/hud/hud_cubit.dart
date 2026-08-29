import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/app_bloc_observer.dart';
import '../../core/adas_channel.dart';
import '../../domain/collision_warning.dart';
import '../../domain/distance_estimator.dart';
import '../../domain/lead_departure.dart';
import '../../domain/models.dart';
import '../../domain/safe_distance.dart';
import '../../domain/solar.dart';
import '../../services/weather_service.dart';
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

  StreamSubscription<AdasFrame>? _frameSub;
  StreamSubscription<Position>? _posSub;
  Timer? _weatherTimer;
  DateTime? _lastGeocodeAt;
  double? _lastGeocodeLat;
  double? _lastGeocodeLon;

  static const _weatherRefresh = Duration(minutes: 15);
  static const _geocodeMinInterval = Duration(minutes: 2);
  static const _geocodeMinMoveMeters = 1000.0;

  Future<void> start() async {
    await AdasChannel.start();
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
    final lead = _estimator.pickLead(frame);
    final distance = lead == null ? null : _estimator.estimate(lead);

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

    if (alert != state.alert) {
      crashlyticsLog('HudCubit: alert ${state.alert} -> $alert '
          '(d=${distance?.toStringAsFixed(1)}m v=${state.speedKmh.toStringAsFixed(0)}km/h)');
    }
    if (departed) {
      crashlyticsLog('HudCubit: lead departed');
    }

    emit(state.copyWith(
      mock: frame.mock,
      leadDistanceM: distance,
      requiredGapM: SafeDistance.legalMinimumMeters(state.speedKmh),
      alert: alert,
      departureCount: departed ? state.departureCount + 1 : null,
    ));
  }

  void _onPosition(Position pos) {
    final speedKmh = pos.speed < 0 ? 0.0 : pos.speed * 3.6;
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
    await _frameSub?.cancel();
    await _posSub?.cancel();
    _weatherTimer?.cancel();
    await AdasChannel.stop();
    return super.close();
  }
}
