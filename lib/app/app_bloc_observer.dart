import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Global observer: every bloc transition becomes a Crashlytics breadcrumb,
/// so each crash report arrives with the state history that led to it.
///
/// High-frequency cubits (the 10 Hz HUD stream) are excluded here and log
/// their own significant transitions instead — see HudCubit.
class AppBlocObserver extends BlocObserver {
  static const _noisyBlocs = {'HudCubit'};

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final name = bloc.runtimeType.toString();
    if (_noisyBlocs.contains(name)) return;
    final line = '$name: ${change.currentState} -> ${change.nextState}';
    debugPrint('[bloc] $line');
    crashlyticsLog(line);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: 'Unhandled error in ${bloc.runtimeType}',
        );
      }
    } catch (_) {/* Firebase not configured */}
    super.onError(bloc, error, stackTrace);
  }
}

/// Safe Crashlytics breadcrumb — no-op until Firebase is configured.
void crashlyticsLog(String message) {
  try {
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.log(message);
    }
  } catch (_) {/* Firebase not configured */}
}
