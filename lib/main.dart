import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/app_bloc_observer.dart';
import 'features/hud/hud_cubit.dart';
import 'features/hud/hud_screen.dart';
import 'features/settings/settings_cubit.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase/Crashlytics: activates only after `flutterfire configure` has
  // generated the platform config (see README, "Firebase"). Guarded so the
  // app runs fully offline and before Firebase is set up.
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    debugPrint('Firebase not configured yet — running without Crashlytics.');
  }

  Bloc.observer = AppBlocObserver();
  runApp(const PhoneAdasApp());
}

class PhoneAdasApp extends StatefulWidget {
  const PhoneAdasApp({super.key});

  @override
  State<PhoneAdasApp> createState() => _PhoneAdasAppState();
}

class _PhoneAdasAppState extends State<PhoneAdasApp> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit()..load()),
        BlocProvider(create: (_) => HudCubit()..start()),
      ],
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (prev, next) => prev.sensitivity != next.sensitivity,
        listener: (context, settings) => context
            .read<HudCubit>()
            .applyDisplaySensitivity(settings.sensitivity),
        child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsCubit>().state;
          final isDay = context
              .select<HudCubit, bool>((cubit) => cubit.state.isDay);
          return MaterialApp(
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)!.appTitle,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: settings.localeOverride,
            theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
            darkTheme:
                ThemeData(brightness: Brightness.dark, useMaterial3: true),
            themeMode: settings.resolveThemeMode(isDay: isDay),
            home: const HudScreen(),
          );
        },
        ),
      ),
    );
  }
}
