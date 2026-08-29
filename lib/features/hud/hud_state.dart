import 'package:equatable/equatable.dart';

import '../../domain/collision_warning.dart';
import '../../services/weather_service.dart';

enum HudStatus { initializing, running, locationDenied }

class HudState extends Equatable {
  const HudState({
    this.status = HudStatus.initializing,
    this.mock = false,
    this.leadDistanceM,
    this.requiredGapM = 0,
    this.alert = AdasAlert.none,
    this.departureCount = 0,
    this.speedKmh = 0,
    this.lat,
    this.lon,
    this.areaName,
    this.weather,
    this.isDay = true,
  });

  final HudStatus status;

  /// True while the native core emits synthetic detections (no ML model yet).
  final bool mock;
  final double? leadDistanceM;
  final double requiredGapM;
  final AdasAlert alert;

  /// Increments once per "lead vehicle departed while stopped" event.
  final int departureCount;
  final double speedKmh;
  final double? lat;
  final double? lon;
  final String? areaName;
  final WeatherSnapshot? weather;
  final bool isDay;

  static const _unset = Object();

  HudState copyWith({
    HudStatus? status,
    bool? mock,
    Object? leadDistanceM = _unset,
    double? requiredGapM,
    AdasAlert? alert,
    int? departureCount,
    double? speedKmh,
    double? lat,
    double? lon,
    String? areaName,
    WeatherSnapshot? weather,
    bool? isDay,
  }) =>
      HudState(
        status: status ?? this.status,
        mock: mock ?? this.mock,
        leadDistanceM: identical(leadDistanceM, _unset)
            ? this.leadDistanceM
            : leadDistanceM as double?,
        requiredGapM: requiredGapM ?? this.requiredGapM,
        alert: alert ?? this.alert,
        departureCount: departureCount ?? this.departureCount,
        speedKmh: speedKmh ?? this.speedKmh,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        areaName: areaName ?? this.areaName,
        weather: weather ?? this.weather,
        isDay: isDay ?? this.isDay,
      );

  @override
  List<Object?> get props => [
        status,
        mock,
        leadDistanceM,
        requiredGapM,
        alert,
        departureCount,
        speedKmh,
        lat,
        lon,
        areaName,
        weather?.tempC,
        weather?.kind,
        weather?.isStale,
        isDay,
      ];
}
