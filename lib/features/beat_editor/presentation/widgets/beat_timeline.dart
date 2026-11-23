import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';
import 'timeline_painter.dart';

/// Zoomable waveform: pinch to zoom, drag to scrub under the fixed playhead.
/// Playhead and zoom come from the cubit's notifiers, so only the painter
/// (and the selected-marker card) update per frame.
class BeatTimeline extends HookWidget {
  const BeatTimeline({super.key, required this.state});

  final BeatEditorReady state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BeatEditorCubit>();
    final zoomAtStart = useRef(cubit.zoom.value);
    final scrubSample = useRef(0.0);
    final pinching = useRef(false);

    return Semantics(
      label: 'Waveform. Tap a marker to edit it. Pinch to zoom, drag to scrub.',
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          // Zoom limits depend on the view width; report it after layout.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => cubit.setViewportWidth(width),
          );
          final selected = state.selectedIndex;
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => cubit.selectBeat(
                      TimelinePainter.beatAt(
                        project: state.project,
                        playheadSample: cubit.playheadSample,
                        zoom: cubit.zoom.value,
                        dx: d.localPosition.dx,
                        dy: d.localPosition.dy,
                        width: width,
                      ),
                    ),
                    onScaleStart: (d) {
                      zoomAtStart.value = cubit.zoom.value;
                      scrubSample.value = cubit.playheadSample.toDouble();
                      pinching.value = d.pointerCount > 1;
                      if (!pinching.value) cubit.scrubStart();
                    },
                    onScaleUpdate: (d) {
                      if (d.pointerCount > 1) {
                        if (!pinching.value) {
                          // A second finger joined a drag: finish the scrub.
                          pinching.value = true;
                          cubit.scrubEnd();
                          zoomAtStart.value = cubit.zoom.value / d.scale;
                        }
                        cubit.setZoom(zoomAtStart.value * d.scale);
                        return;
                      }
                      if (pinching.value) return;
                      scrubSample.value -=
                          d.focalPointDelta.dx / cubit.pxPerSample;
                      cubit.scrubTo(scrubSample.value.round());
                    },
                    onScaleEnd: (_) {
                      if (!pinching.value) cubit.scrubEnd();
                      pinching.value = false;
                    },
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: TimelinePainter(
                        project: state.project,
                        peaks: state.peaks,
                        playhead: cubit.playhead,
                        zoom: cubit.zoom,
                        pcm: cubit.pcmWindow,
                        colors: context.kv,
                        selectedIndex: selected,
                      ),
                    ),
                  ),
                ),
              ),
              if (selected != null &&
                  selected >= 0 &&
                  selected < state.project.beats.length)
                ListenableBuilder(
                  listenable: Listenable.merge([cubit.playhead, cubit.zoom]),
                  builder: (context, _) =>
                      _cardFor(context, cubit, selected, width),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cardFor(
    BuildContext context,
    BeatEditorCubit cubit,
    int index,
    double width,
  ) {
    final beat = state.project.beats[index];
    final x =
        width / 2 + (beat.sample - cubit.playheadSample) * cubit.pxPerSample;
    // Hide the card once its marker has been scrubbed off screen.
    if (x < -20 || x > width + 20) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned(
          left: (x - 104).clamp(8.0, math.max(8.0, width - 216)),
          bottom: 12,
          width: 208,
          height: 46,
          child: IgnorePointer(
            child: BeatInfoCard(
              number: index + 1,
              beat: beat,
              timeMs: state.project.sampleToMs(beat.sample),
              snapped: state.project.isOnGrid(beat.sample),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating card under the selected marker: name, time, haptic hint.
class BeatInfoCard extends StatelessWidget {
  const BeatInfoCard({
    super.key,
    required this.number,
    required this.beat,
    required this.timeMs,
    required this.snapped,
  });

  final int number;
  final Beat beat;
  final int timeMs;
  final bool snapped;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final haptic = switch (beat.type) {
      BeatType.beat => null,
      BeatType.strong || BeatType.downbeat => 'tick',
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
                '${formatClock(timeMs, millis: true)}'
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
  BeatType.downbeat => 'Downbeat',
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

    void seek(double x, double width) =>
        cubit.seekTo((x / width * state.project.sampleCount).round());

    return Semantics(
      label: 'Whole song overview',
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx, c.maxWidth),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx, c.maxWidth),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(c.maxWidth, 32),
              painter: OverviewPainter(
                project: state.project,
                peaks: state.peaks,
                colors: context.kv,
              ),
              foregroundPainter: OverviewViewportPainter(
                sampleCount: state.project.sampleCount,
                sampleRate: state.project.sampleRate,
                playhead: cubit.playhead,
                zoom: cubit.zoom,
                timelineWidth: screenWidth,
                colors: context.kv,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
