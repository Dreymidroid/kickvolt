import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';
import '../../domain/entities/beat.dart';
import 'timeline_painter.dart';

/// Zoomable waveform: pinch to zoom, drag to scrub under the fixed playhead.
class BeatTimeline extends HookWidget {
  const BeatTimeline({super.key, required this.state});

  final BeatEditorReady state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BeatEditorCubit>();
    final zoomAtStart = useRef(state.zoom);
    final scrubMs = useRef(0.0);

    return Semantics(
      label: 'Waveform. Tap a marker to edit it. Pinch to zoom, drag to scrub.',
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          final pxPerMs = state.zoom * kPxPerSecondAt1x / 1000;
          final selected = state.selectedIndex;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => cubit.selectBeat(
                    TimelinePainter.beatAt(
                      project: state.project,
                      playheadMs: state.playheadMs,
                      zoom: state.zoom,
                      dx: d.localPosition.dx,
                      dy: d.localPosition.dy,
                      width: width,
                    ),
                  ),
                  onScaleStart: (_) {
                    zoomAtStart.value = state.zoom;
                    scrubMs.value = state.playheadMs.toDouble();
                  },
                  onScaleUpdate: (d) {
                    if (d.pointerCount > 1) {
                      cubit.setZoom(zoomAtStart.value * d.scale);
                      return;
                    }
                    scrubMs.value -= d.focalPointDelta.dx / pxPerMs;
                    cubit.seekTo(scrubMs.value.round());
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: TimelinePainter(
                      project: state.project,
                      playheadMs: state.playheadMs,
                      zoom: state.zoom,
                      colors: context.kv,
                      selectedIndex: selected,
                    ),
                  ),
                ),
              ),
              if (selected != null) _cardFor(context, selected, width, pxPerMs),
            ],
          );
        },
      ),
    );
  }

  Widget _cardFor(
    BuildContext context,
    int index,
    double width,
    double pxPerMs,
  ) {
    final beat = state.project.beats[index];
    final x = width / 2 + (beat.timeMs - state.playheadMs) * pxPerMs;
    // Hide the card once its marker has been scrubbed off screen.
    if (x < -20 || x > width + 20) return const SizedBox.shrink();
    return Positioned(
      left: (x - 104).clamp(8.0, width - 216),
      bottom: 12,
      width: 208,
      height: 46,
      child: IgnorePointer(
        child: BeatInfoCard(
          number: index + 1,
          beat: beat,
          snapped: state.project.isOnGrid(beat.timeMs),
        ),
      ),
    );
  }
}

/// Floating card under the selected marker: name, time, haptic hint.
class BeatInfoCard extends StatelessWidget {
  const BeatInfoCard({
    super.key,
    required this.number,
    required this.beat,
    required this.snapped,
  });

  final int number;
  final Beat beat;
  final bool snapped;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final haptic = switch (beat.type) {
      BeatType.beat => null,
      BeatType.strong => 'tick',
      BeatType.drop => 'thud',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kv.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kv.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beat $number · ${beatTypeLabel(beat.type)}',
                style: KvText.ui(
                  size: 13,
                  weight: FontWeight.w700,
                  color: kv.text1,
                ),
              ),
              Text(
                '${formatClock(beat.timeMs, millis: true)}'
                ' · ${snapped ? 'snapped' : 'off grid'}',
                style: KvText.mono(size: 12, color: kv.text2),
              ),
            ],
          ),
          if (haptic != null)
            Row(
              children: [
                KvIcon(KvIcons.vibrate, size: 16, color: kv.volt),
                const SizedBox(width: 4),
                Text(
                  haptic,
                  style: KvText.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: kv.volt,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String beatTypeLabel(BeatType t) => switch (t) {
  BeatType.beat => 'Beat',
  BeatType.strong => 'Strong',
  BeatType.drop => 'Drop',
};

class OverviewStrip extends StatelessWidget {
  const OverviewStrip({
    super.key,
    required this.state,
    required this.screenWidth,
  });

  final BeatEditorReady state;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BeatEditorCubit>();
    final visibleMs = screenWidth / (state.zoom * kPxPerSecondAt1x / 1000);

    void seek(double x, double width) =>
        cubit.seekTo((x / width * state.project.durationMs).round());

    return Semantics(
      label: 'Whole song overview',
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx, c.maxWidth),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx, c.maxWidth),
          child: CustomPaint(
            size: Size(c.maxWidth, 32),
            painter: OverviewPainter(
              project: state.project,
              playheadMs: state.playheadMs,
              visibleMs: visibleMs,
              colors: context.kv,
            ),
          ),
        ),
      ),
    );
  }
}
