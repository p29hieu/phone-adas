import 'dart:ui' show Rect;

import 'package:equatable/equatable.dart';

import '../../domain/collision_warning.dart';
import '../../domain/lane_monitor.dart';
import '../../domain/models.dart';
import '../../services/weather_service.dart';

enum HudStatus { initializing, running, locationDenied }

/// A detected vehicle with its estimated distance, ready for the AR overlay.
class TrackedVehicle extends Equatable {
  const TrackedVehicle({
    required this.cls,
    required this.rect,
    required this.distanceM,
    required this.isLead,
  });

  final String cls;

  /// Bounding box in source-frame pixels (see HudState.frameW/frameH).
  final Rect rect;
  final double distanceM;

  /// True for the vehicle used for gap/collision alerts (in our lane).
  final bool isLead;

  @override
  List<Object?> get props => [cls, rect, distanceM, isLead];
}

class HudState extends Equatable {
  const HudState({
    this.status = HudStatus.initializing,
    this.textureId,
    this.mock = false,
    this.leadDistanceM,
    this.vehicles = const [],
    this.frameW = 1920,
    this.frameH = 1080,
    this.requiredGapM = 0,
    this.alert = AdasAlert.none,
    this.departureCount = 0,
    this.lane,
    this.laneDebug,
    this.laneStatus = LaneStatus.unknown,
    this.laneEventCount = 0,
    this.speedKmh = 0,
    this.speedOverrideKmh,
    this.detectedCars = 0,
    this.detectedMotos = 0,
    this.lat,
    this.lon,
    this.areaName,
    this.weather,
    this.isDay = true,
    this.isRecording = false,
    this.recordingStartedAt,
    this.versionLabel,
  });

  final HudStatus status;

  /// Flutter texture id of the live camera preview (null = no preview).
  final int? textureId;

  /// True while the native core emits synthetic detections (no ML model yet).
  final bool mock;
  final double? leadDistanceM;

  /// All valid detections with distances, for the AR overlay.
  final List<TrackedVehicle> vehicles;
  final int frameW;
  final int frameH;
  final double requiredGapM;
  final AdasAlert alert;

  /// Increments once per "lead vehicle departed while stopped" event.
  final int departureCount;

  /// Ego-lane estimate for the test-mode overlay (null = not detected).
  final LaneObservation? lane;

  /// Human-readable lane-detector diagnostics for the dev-mode chip.
  final String? laneDebug;
  final LaneStatus laneStatus;

  /// Increments once per lane-departure event (test-mode warning).
  final int laneEventCount;
  final double speedKmh;

  /// Test-mode manual speed (null = GPS drives the speed).
  final double? speedOverrideKmh;

  /// Raw recognition counts (all confident detections, pre lane filter) —
  /// what the dev-mode chip shows.
  final int detectedCars;
  final int detectedMotos;
  final double? lat;
  final double? lon;
  final String? areaName;
  final WeatherSnapshot? weather;
  final bool isDay;
  final bool isRecording;
  final DateTime? recordingStartedAt;

  /// "v1.1.0 (2)" — for the dev-mode chip.
  final String? versionLabel;

  static const _unset = Object();

  HudState copyWith({
    HudStatus? status,
    int? textureId,
    bool? mock,
    Object? leadDistanceM = _unset,
    List<TrackedVehicle>? vehicles,
    int? frameW,
    int? frameH,
    double? requiredGapM,
    AdasAlert? alert,
    int? departureCount,
    Object? lane = _unset,
    String? laneDebug,
    LaneStatus? laneStatus,
    int? laneEventCount,
    double? speedKmh,
    Object? speedOverrideKmh = _unset,
    int? detectedCars,
    int? detectedMotos,
    double? lat,
    double? lon,
    String? areaName,
    WeatherSnapshot? weather,
    bool? isDay,
    bool? isRecording,
    Object? recordingStartedAt = _unset,
    String? versionLabel,
  }) =>
      HudState(
        status: status ?? this.status,
        textureId: textureId ?? this.textureId,
        mock: mock ?? this.mock,
        leadDistanceM: identical(leadDistanceM, _unset)
            ? this.leadDistanceM
            : leadDistanceM as double?,
        vehicles: vehicles ?? this.vehicles,
        frameW: frameW ?? this.frameW,
        frameH: frameH ?? this.frameH,
        requiredGapM: requiredGapM ?? this.requiredGapM,
        alert: alert ?? this.alert,
        departureCount: departureCount ?? this.departureCount,
        lane: identical(lane, _unset) ? this.lane : lane as LaneObservation?,
        laneDebug: laneDebug ?? this.laneDebug,
        laneStatus: laneStatus ?? this.laneStatus,
        laneEventCount: laneEventCount ?? this.laneEventCount,
        speedKmh: speedKmh ?? this.speedKmh,
        speedOverrideKmh: identical(speedOverrideKmh, _unset)
            ? this.speedOverrideKmh
            : speedOverrideKmh as double?,
        detectedCars: detectedCars ?? this.detectedCars,
        detectedMotos: detectedMotos ?? this.detectedMotos,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        areaName: areaName ?? this.areaName,
        weather: weather ?? this.weather,
        isDay: isDay ?? this.isDay,
        isRecording: isRecording ?? this.isRecording,
        recordingStartedAt: identical(recordingStartedAt, _unset)
            ? this.recordingStartedAt
            : recordingStartedAt as DateTime?,
        versionLabel: versionLabel ?? this.versionLabel,
      );

  @override
  List<Object?> get props => [
        status,
        textureId,
        mock,
        leadDistanceM,
        vehicles,
        frameW,
        frameH,
        requiredGapM,
        alert,
        departureCount,
        lane?.offset,
        lane?.conf,
        laneDebug,
        laneStatus,
        laneEventCount,
        speedKmh,
        speedOverrideKmh,
        detectedCars,
        detectedMotos,
        lat,
        lon,
        areaName,
        weather?.tempC,
        weather?.kind,
        weather?.isStale,
        isDay,
        isRecording,
        recordingStartedAt,
        versionLabel,
      ];
}
