import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../beat_detection/beat_detection.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';

/// Context panel shown on the Edit tab while playing (`EditorPlaying.png`).
///
/// Repaints the beat number and 4 bar dots from [BeatEditorCubit.playhead]
/// directly so playback never triggers Cubit state emissions.
class PlayingPanel extends StatelessWidget {
  const PlayingPanel({super.key, required this.state});

  final BeatEditorReady state;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final beats = state.project.beats;
    final visible = visibleBeatIndices(state.project);
    final totalVisible = visible.length;

    // Bar-position anchor: index in `visible` of the first downbeat, else 0.
    var anchorVisibleIdx = 0;
    for (var vi = 0; vi < visible.length; vi++) {
      if (beats[visible[vi]].type == BeatType.downbeat) {
        anchorVisibleIdx = vi;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: cubit.playhead,
          builder: (context, ph, _) {
            // Find last visible beat at or before playhead (1-based n).
            var currentVisibleIdx = -1;
            var lo = 0;
            var hi = visible.length;
            while (lo < hi) {
              final mid = (lo + hi) >> 1;
              if (beats[visible[mid]].sample <= ph) {
                currentVisibleIdx = mid;
                lo = mid + 1;
              } else {
                hi = mid;
              }
            }

            final n = currentVisibleIdx + 1;
            final barPos = currentVisibleIdx < 0
                ? -1
                : ((currentVisibleIdx - anchorVisibleIdx) % 4 + 4) % 4;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: kv.surface1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kv.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEAT',
                        style: KvText.ui(
                          size: 11,
                          weight: FontWeight.w700,
                          color: kv.text3,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$n',
                              style: KvText.mono(
                                size: 34,
                                weight: FontWeight.w700,
                                color: kv.volt,
                                height: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: ' / $totalVisible',
                              style: KvText.mono(
                                size: 16,
                                weight: FontWeight.w600,
                                color: kv.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    label: barPos >= 0
                        ? 'Beat ${barPos + 1} of 4 in this bar'
                        : 'Before first beat',
                    child: Row(
                      children: [
                        for (var dot = 0; dot < 4; dot++) ...[
                          if (dot > 0) const SizedBox(width: 8),
                          _BarDot(active: dot == barPos),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            KvIcon(KvIcons.vibrate, size: 16, color: kv.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Each beat ticks as it passes. Tap pause, then fix what’s off.',
                style: KvText.ui(size: 13, color: kv.text2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarDot extends StatelessWidget {
  const _BarDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final size = active ? 28.0 : 20.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? kv.volt : kv.surface3,
        boxShadow: active
            ? [BoxShadow(color: kv.voltGlow, blurRadius: 6)]
            : null,
      ),
    );
  }
}
