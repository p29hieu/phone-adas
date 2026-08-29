import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_bloc_observer.dart';
import '../../core/adas_channel.dart';
import '../../domain/calibration.dart';
import '../../domain/distance_estimator.dart';
import '../../domain/models.dart';

enum CalibStep { intro, aiming, sampling, result }

enum CalibError { none, tooFewSamples, unstable, inconsistent }

class CalibrationState extends Equatable {
  const CalibrationState({
    this.step = CalibStep.intro,
    this.pointIndex = 0,
    this.progress = 0,
    this.liveRawM,
    this.error = CalibError.none,
    this.result,
    this.savedScale,
  });

  final CalibStep step;

  /// 0-based index into Calibration.referenceDistancesM.
  final int pointIndex;
  final double progress;

  /// Live uncalibrated reading of the aimed vehicle, null when none seen.
  final double? liveRawM;
  final CalibError error;
  final CalibrationResult? result;

  /// Currently persisted scale (null = uncalibrated).
  final double? savedScale;

  double get targetDistanceM => Calibration.referenceDistancesM[pointIndex];

  static const _unset = Object();

  CalibrationState copyWith({
    CalibStep? step,
    int? pointIndex,
    double? progress,
    Object? liveRawM = _unset,
    CalibError? error,
    Object? result = _unset,
    Object? savedScale = _unset,
  }) =>
      CalibrationState(
        step: step ?? this.step,
        pointIndex: pointIndex ?? this.pointIndex,
        progress: progress ?? this.progress,
        liveRawM:
            identical(liveRawM, _unset) ? this.liveRawM : liveRawM as double?,
        error: error ?? this.error,
        result: identical(result, _unset)
            ? this.result
            : result as CalibrationResult?,
        savedScale: identical(savedScale, _unset)
            ? this.savedScale
            : savedScale as double?,
      );

  @override
  List<Object?> get props => [
        step,
        pointIndex,
        progress,
        liveRawM,
        error,
        result?.scale,
        result?.isValid,
        savedScale,
      ];
}

/// Drives the two-point guided calibration. Reads the same detection stream
/// as the HUD but through its own *uncalibrated* estimator (scale = 1), so
/// recalibration is always measured from raw values.
class CalibrationCubit extends Cubit<CalibrationState> {
  CalibrationCubit() : super(const CalibrationState());

  static const prefsKey = 'distance_scale_v1';
  static const _sampleDuration = Duration(seconds: 3);

  final DistanceEstimator _rawEstimator = DistanceEstimator();
  final List<CalibrationPoint> _points = [];
  CalibrationSampler? _sampler;
  StreamSubscription<AdasFrame>? _sub;
  Timer? _sampleTimer;
  DateTime? _sampleStart;

  Future<void> begin() async {
    final prefs = await SharedPreferences.getInstance();
    emit(state.copyWith(savedScale: prefs.getDouble(prefsKey)));
    _sub = AdasChannel.frames.listen(_onFrame);
  }

  void _onFrame(AdasFrame frame) {
    if (frame.fx != null && frame.fx! > 0) {
      _rawEstimator.fPx = frame.fx!;
    }
    final lead = _rawEstimator.pickLead(frame);
    final raw = lead == null ? null : _rawEstimator.estimate(lead);
    if (state.step == CalibStep.aiming) {
      emit(state.copyWith(liveRawM: raw));
    } else if (state.step == CalibStep.sampling) {
      if (raw != null) _sampler?.add(raw);
      final elapsed = DateTime.now().difference(_sampleStart!);
      emit(state.copyWith(
        liveRawM: raw,
        progress: (elapsed.inMilliseconds / _sampleDuration.inMilliseconds)
            .clamp(0.0, 1.0),
      ));
    }
  }

  void startFlow() {
    _points.clear();
    emit(state.copyWith(
      step: CalibStep.aiming,
      pointIndex: 0,
      error: CalibError.none,
      result: null,
    ));
  }

  void startSampling() {
    _sampler = CalibrationSampler();
    _sampleStart = DateTime.now();
    emit(state.copyWith(
        step: CalibStep.sampling, progress: 0, error: CalibError.none));
    _sampleTimer = Timer(_sampleDuration, _finishSampling);
  }

  void _finishSampling() {
    final outcome = _sampler?.finish();
    _sampleTimer = null;
    switch (outcome?.status) {
      case SamplerStatus.stable:
        _points.add(CalibrationPoint(
          trueDistanceM: state.targetDistanceM,
          rawDistanceM: outcome!.medianM,
        ));
        if (state.pointIndex + 1 < Calibration.referenceDistancesM.length) {
          emit(state.copyWith(
            step: CalibStep.aiming,
            pointIndex: state.pointIndex + 1,
            progress: 0,
          ));
        } else {
          final result = Calibration.compute(_points);
          crashlyticsLog(
              'Calibration: scale=${result.scale.toStringAsFixed(3)} '
              'spread=${result.spreadRatio.toStringAsFixed(3)} '
              'valid=${result.isValid}');
          emit(state.copyWith(
            step: CalibStep.result,
            result: result,
            error: result.isValid ? CalibError.none : CalibError.inconsistent,
          ));
        }
      case SamplerStatus.tooFewSamples:
        emit(state.copyWith(
            step: CalibStep.aiming,
            progress: 0,
            error: CalibError.tooFewSamples));
      case SamplerStatus.unstable:
        emit(state.copyWith(
            step: CalibStep.aiming, progress: 0, error: CalibError.unstable));
      case null:
        emit(state.copyWith(step: CalibStep.aiming, progress: 0));
    }
  }

  Future<void> save() async {
    final result = state.result;
    if (result == null || !result.isValid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(prefsKey, result.scale);
    emit(state.copyWith(savedScale: result.scale));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    emit(state.copyWith(savedScale: null, step: CalibStep.intro));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sampleTimer?.cancel();
    return super.close();
  }
}
