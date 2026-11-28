import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../bloc/import_cubit.dart';
import '../../domain/entities/import_failure.dart';
import '../../domain/entities/picked_source.dart';
import '../widgets/library_track_sheet.dart';

/// Import progress. Pops with an [ImportFailure] on error, with nothing on
/// cancel, and replaces itself with the editor on success.
@RoutePage()
class AnalyzingScreen extends StatelessWidget {
  const AnalyzingScreen({super.key, required this.source, this.cubit});

  final PickedSource source;

  /// For tests.
  final ImportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? (ImportCubit(source: source)..start()),
      child: const AnalyzingView(),
    );
  }
}

class AnalyzingView extends StatelessWidget {
  const AnalyzingView({super.key});

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<ImportCubit>();
    return BlocConsumer<ImportCubit, ImportState>(
      listener: (context, state) {
        // The listener runs before the builder, while PopScope still has
        // canPop: false from the importing state, so an immediate maybePop
        // is refused and the screen sticks at 100 %. Pop after the rebuild.
        void popAfterRebuild([Object? result]) =>
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.router.maybePop(result);
            });
        switch (state) {
          case ImportDone(:final song):
            context.router.replace(BeatEditorRoute(projectId: song.projectId));
          case ImportFailed(:final failure):
            popAfterRebuild(failure);
          case ImportCancelledState():
            popAfterRebuild();
          case ImportImporting():
            break;
        }
      },
      builder: (context, state) {
        final (source, progress, step, detectedBpm) = switch (state) {
          ImportImporting(
            :final source,
            :final progress,
            :final step,
            :final detectedBpm,
          ) =>
            (source, progress, step, detectedBpm),
          _ => (null, 1.0, ImportStep.sections, null),
        };
        return PopScope(
          canPop: state is! ImportImporting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cubit.cancel();
          },
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        KvIconButton(
                          icon: KvIcons.close,
                          tooltip: 'Cancel import',
                          onPressed: cubit.cancel,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source?.displayName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: KvText.ui(
                                  size: 16,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if (source?.durationMs != null)
                                Text(
                                  formatDuration(source!.durationMs!),
                                  style: KvText.mono(size: 12, color: kv.text2),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    ProgressRing(progress: progress),
                    const SizedBox(height: 28),
                    Text(
                      'Finding your beats…',
                      style: KvText.ui(size: 26, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usually takes a few seconds.',
                      style: KvText.ui(size: 15, color: kv.text2),
                    ),
                    const Spacer(flex: 3),
                    _Steps(
                      step: step,
                      allDone: progress >= 1.0,
                      detectedBpm: detectedBpm,
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: KvSecondaryButton(
                        label: 'Cancel',
                        onPressed: cubit.cancel,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.step, required this.allDone, this.detectedBpm});

  final ImportStep step;
  final bool allDone;
  final double? detectedBpm;

  _StepState _stateFor(ImportStep target) {
    if (allDone || step.index > target.index) return _StepState.done;
    if (step.index == target.index) return _StepState.active;
    return _StepState.pending;
  }

  static String _formatBpm(double bpm) => bpm == bpm.roundToDouble()
      ? '${bpm.round()} BPM'
      : '${bpm.toStringAsFixed(1)} BPM';

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kv.border),
      ),
      child: Column(
        children: [
          _Step('Reading the audio', _stateFor(ImportStep.reading)),
          _Step(
            'Finding the tempo',
            _stateFor(ImportStep.tempo),
            trailing: detectedBpm != null ? _formatBpm(detectedBpm!) : null,
          ),
          _Step('Spotting strong beats and drops', _stateFor(ImportStep.beats)),
          _Step('Splitting into sections', _stateFor(ImportStep.sections)),
        ],
      ),
    );
  }
}

enum _StepState { pending, active, done }

class _Step extends StatelessWidget {
  const _Step(this.label, this.state, {this.trailing});

  final String label;
  final _StepState state;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final Widget dot = switch (state) {
      _StepState.done => Container(
        decoration: BoxDecoration(color: kv.volt, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: KvIcon(KvIcons.check, size: 14, color: kv.onVolt),
      ),
      _StepState.active => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kv.volt, width: 2),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: kv.volt, shape: BoxShape.circle),
        ),
      ),
      _StepState.pending => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kv.border, width: 2),
        ),
      ),
    };
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox.square(dimension: 24, child: dot),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: KvText.ui(
                size: 15,
                weight: state == _StepState.active
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: state == _StepState.pending ? kv.text3 : kv.text1,
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: KvText.mono(size: 14, color: kv.volt)),
        ],
      ),
    );
  }
}

/// 120 px volt progress ring with a glowing arc and a percentage.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 120});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final pct = (progress * 100).floor().clamp(0, 100);
    return Semantics(
      label: 'Import progress',
      value: '$pct%',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress,
            track: kv.surface3,
            arc: kv.volt,
          ),
          child: Center(
            child: Text(
              '$pct%',
              style: KvText.mono(size: 24, weight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.arc,
  });

  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final paint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = arc.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.arc != arc;
}
