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
        switch (state) {
          case ImportDone(:final song):
            context.router.replace(BeatEditorRoute(projectId: song.projectId));
          case ImportFailed(:final failure):
            context.router.maybePop(failure);
          case ImportCancelledState():
            context.router.maybePop();
          case ImportImporting():
            break;
        }
      },
      builder: (context, state) {
        final (source, progress) = switch (state) {
          ImportImporting(:final source, :final progress) => (source, progress),
          _ => (null, 1.0),
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
                    // Only decoding exists so far; detection steps arrive in M4.
                    _Steps(readingDone: progress >= 1),
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
  const _Steps({required this.readingDone});

  final bool readingDone;

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
          _Step(
            'Reading the audio',
            readingDone ? _StepState.done : _StepState.active,
          ),
          const _Step('Finding the tempo', _StepState.pending),
          const _Step('Spotting strong beats and drops', _StepState.pending),
          const _Step('Splitting into sections', _StepState.pending),
        ],
      ),
    );
  }
}

enum _StepState { pending, active, done }

class _Step extends StatelessWidget {
  const _Step(this.label, this.state);

  final String label;
  final _StepState state;

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
