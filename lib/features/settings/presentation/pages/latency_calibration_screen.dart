import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/latency_calibration_cubit.dart';
import '../../data/output_route_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/latency_calibration.dart';

@RoutePage()
class LatencyCalibrationScreen extends StatelessWidget {
  const LatencyCalibrationScreen({super.key, this.cubit});

  final LatencyCalibrationCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? (LatencyCalibrationCubit()..init()),
      child: const _LatencyCalibrationView(),
    );
  }
}

class _LatencyCalibrationView extends StatelessWidget {
  const _LatencyCalibrationView();

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Scaffold(
      backgroundColor: kv.background,
      body: SafeArea(
        child: BlocBuilder<LatencyCalibrationCubit, LatencyCalibrationState>(
          builder: (context, state) => switch (state) {
            LatencyCalibrationLoading() => Center(
              child: CircularProgressIndicator(color: kv.volt),
            ),
            LatencyCalibrationError(:final error) => _ErrorBody(error: error),
            final LatencyCalibrationReady s => _CalibrationBody(state: s),
          },
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Calibration unavailable',
            style: KvText.heading(size: 20, color: kv.text1),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: KvText.ui(size: 14, color: kv.error),
          ),
          const SizedBox(height: 24),
          KvSecondaryButton(
            label: 'Back',
            icon: KvIcons.chevronLeft,
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}

class _CalibrationBody extends StatelessWidget {
  const _CalibrationBody({required this.state});

  final LatencyCalibrationReady state;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<LatencyCalibrationCubit>();
    final showBtWarning = shouldShowBluetoothWarning(
      currentOutput: state.outputKind,
      calibratedOn: state.calibratedOn,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              KvIconButton(
                icon: KvIcons.chevronLeft,
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              Text(
                'Latency calibration',
                style: KvText.heading(size: 20, color: kv.text1),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Calibrate with the headphones you'll edit with.",
                  style: KvText.ui(size: 15, color: kv.text2),
                ),
                const SizedBox(height: 12),
                _OutputRouteCard(
                  outputKind: state.outputKind,
                  reportedLatencyMs: state.reportedOutputLatencyMs,
                ),
                if (showBtWarning) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kv.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kv.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        KvIcon(
                          KvIcons.alertCircle,
                          size: 18,
                          color: kv.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bluetooth adds 150–300 ms of delay. Calibrate with these headphones.',
                            style: KvText.ui(size: 13, color: kv.text1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: switch (state.status) {
                    CalibrationStatus.needMoreTaps => _TapPhase(state: state),
                    CalibrationStatus.ready => _ResultPhase(
                      offsetMs: state.measuredOffsetMs!,
                      onSave: () async {
                        final ok = await cubit.save();
                        if (ok && context.mounted) {
                          Navigator.maybePop(context, state.measuredOffsetMs);
                        }
                      },
                      onRetry: cubit.tryAgain,
                    ),
                    CalibrationStatus.tooUneven => _UnevenPhase(
                      onRetry: cubit.tryAgain,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OutputRouteCard extends StatelessWidget {
  const _OutputRouteCard({
    required this.outputKind,
    required this.reportedLatencyMs,
  });

  final OutputKind outputKind;
  final int? reportedLatencyMs;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kv.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KvIcon(KvIcons.volume, size: 16, color: kv.volt),
              const SizedBox(width: 8),
              Text(
                outputKindLabel(outputKind),
                style: KvText.ui(
                  size: 14,
                  weight: FontWeight.w600,
                  color: kv.text1,
                ),
              ),
            ],
          ),
          if (reportedLatencyMs != null) ...[
            const SizedBox(height: 4),
            Text(
              'Device-reported delay: $reportedLatencyMs ms',
              style: KvText.mono(size: 12, color: kv.text2),
            ),
          ],
        ],
      ),
    );
  }
}

class _TapPhase extends StatelessWidget {
  const _TapPhase({required this.state});

  final LatencyCalibrationReady state;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<LatencyCalibrationCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: state.playing ? (_) => cubit.recordTap() : null,
            child: Semantics(
              button: true,
              label: 'Calibration tap pad',
              child: Container(
                decoration: BoxDecoration(
                  color: state.playing
                      ? kv.volt.withValues(alpha: 0.09)
                      : kv.surface1,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: state.playing
                        ? kv.volt.withValues(alpha: 0.5)
                        : kv.border,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.playing ? 'TAP' : 'READY',
                      style: KvText.heading(
                        size: 44,
                        color: state.playing ? kv.volt : kv.text3,
                      ).copyWith(letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.playing
                          ? 'Tap in time with every click'
                          : 'Press Play, then tap along with the clicks',
                      style: KvText.ui(size: 14, color: kv.text2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${state.validTapCount} / ${state.requiredTaps} taps',
                      style: KvText.mono(
                        size: 16,
                        weight: FontWeight.w700,
                        color: kv.volt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        KvPrimaryButton(
          label: state.playing ? 'Pause' : 'Play clicks (100 BPM)',
          icon: state.playing ? KvIcons.pause : KvIcons.play,
          onPressed: state.playbackUnavailable ? null : cubit.togglePlay,
        ),
      ],
    );
  }
}

class _ResultPhase extends StatelessWidget {
  const _ResultPhase({
    required this.offsetMs,
    required this.onSave,
    required this.onRetry,
  });

  final int offsetMs;
  final VoidCallback onSave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kv.surface1,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kv.volt.withValues(alpha: 0.45)),
          ),
          child: Column(
            children: [
              Text(
                'Your lag fix: $offsetMs ms',
                textAlign: TextAlign.center,
                style: KvText.heading(size: 26, color: kv.volt),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap-to-mark will shift each tap earlier by $offsetMs ms.',
                textAlign: TextAlign.center,
                style: KvText.ui(size: 14, color: kv.text2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        KvPrimaryButton(label: 'Save', icon: KvIcons.check, onPressed: onSave),
        const SizedBox(height: 10),
        KvSecondaryButton(label: 'Try again', onPressed: onRetry),
      ],
    );
  }
}

class _UnevenPhase extends StatelessWidget {
  const _UnevenPhase({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kv.surface1,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kv.warning.withValues(alpha: 0.45)),
          ),
          child: Column(
            children: [
              KvIcon(KvIcons.alertCircle, size: 32, color: kv.warning),
              const SizedBox(height: 12),
              Text(
                'Taps were too uneven, try again',
                textAlign: TextAlign.center,
                style: KvText.heading(size: 20, color: kv.text1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        KvPrimaryButton(label: 'Try again', onPressed: onRetry),
      ],
    );
  }
}
