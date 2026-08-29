import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cookbook/hud_numeral.dart';
import '../../l10n/app_localizations.dart';
import 'calibration_cubit.dart';

/// Guided two-point distance calibration ("Hiệu chỉnh thông số").
class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key, required this.textureId});

  /// Live camera preview texture from the HUD (null on simulator).
  final int? textureId;

  static String formatPercent(double scale) {
    final pct = (scale - 1) * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CalibrationCubit()..begin(),
      child: _CalibrationView(textureId: textureId),
    );
  }
}

class _CalibrationView extends StatelessWidget {
  const _CalibrationView({required this.textureId});

  final int? textureId;

  String _errorText(AppLocalizations l10n, CalibError error) =>
      switch (error) {
        CalibError.tooFewSamples => l10n.calibErrTooFew,
        CalibError.unstable => l10n.calibErrUnstable,
        CalibError.inconsistent => l10n.calibErrInconsistent,
        CalibError.none => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: Text(l10n.settingsCalibration),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (textureId != null)
            Texture(textureId: textureId!)
          else
            const ColoredBox(color: Color(0xFF15181D)),
          // Center reticle: aim the target car here.
          Center(
            child: Container(
              width: 120,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BlocBuilder<CalibrationCubit, CalibrationState>(
                builder: (context, state) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xE6111417),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _StepContent(
                    state: state,
                    l10n: l10n,
                    errorText: _errorText(l10n, state.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.state,
    required this.l10n,
    required this.errorText,
  });

  final CalibrationState state;
  final AppLocalizations l10n;
  final String errorText;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CalibrationCubit>();
    const white = TextStyle(color: Colors.white, fontSize: 15, height: 1.4);
    const dim = TextStyle(color: Colors.white70, fontSize: 14);

    switch (state.step) {
      case CalibStep.intro:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.calibIntro, style: white),
            const SizedBox(height: 12),
            if (state.savedScale != null) ...[
              Text(
                l10n.calibCurrent(
                    CalibrationScreen.formatPercent(state.savedScale!)),
                style: dim,
              ),
              TextButton(
                onPressed: cubit.reset,
                child: Text(l10n.calibReset),
              ),
            ],
            FilledButton(
              onPressed: cubit.startFlow,
              child: Text(l10n.calibStart),
            ),
          ],
        );

      case CalibStep.aiming:
        final live = state.liveRawM;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.calibPointPrompt(
                  state.pointIndex + 1, state.targetDistanceM.round()),
              style: white.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              live == null
                  ? l10n.calibNoVehicle
                  : l10n.calibDetected(live.toStringAsFixed(1)),
              style: dim,
            ),
            if (errorText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(errorText,
                    style: const TextStyle(
                        color: Colors.orangeAccent, fontSize: 14)),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: live == null ? null : cubit.startSampling,
              child: Text(l10n.calibSample),
            ),
          ],
        );

      case CalibStep.sampling:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.calibSampling, style: white),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: state.progress),
          ],
        );

      case CalibStep.result:
        final result = state.result!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.isValid) ...[
              Center(
                child: HudNumeral(
                  CalibrationScreen.formatPercent(result.scale),
                  size: 40,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.calibResultAdjust(
                    CalibrationScreen.formatPercent(result.scale)),
                style: white,
                textAlign: TextAlign.center,
              ),
            ] else
              Text(errorText,
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: cubit.startFlow,
                    child: Text(l10n.calibRetry),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: result.isValid
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            await cubit.save();
                            messenger.showSnackBar(
                                SnackBar(content: Text(l10n.calibSaved)));
                            navigator.pop(true);
                          }
                        : null,
                    child: Text(l10n.calibSave),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}
