import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';
import 'beat_timeline.dart' show beatTypeLabel;
import 'timeline_painter.dart' show formatClock;

/// Context panel for the Edit tab when a marker is selected: nudge
/// −10/−1/+1/+10 ms, change its type, or delete it.
class BeatInspectorPanel extends StatelessWidget {
  const BeatInspectorPanel({super.key, required this.state});

  final BeatEditorReady state;

  static const _inspectorTypes = [
    BeatType.beat,
    BeatType.strong,
    BeatType.drop,
  ];

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final index = state.selectedIndex!;
    final beat = state.project.beats[index];
    final options = _inspectorTypes.contains(beat.type)
        ? _inspectorTypes
        : [..._inspectorTypes, beat.type];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Beat ${index + 1}',
              style: KvText.ui(
                size: 17,
                weight: FontWeight.w700,
                color: kv.text1,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatClock(state.project.sampleToMs(beat.sample), millis: true),
              style: KvText.mono(size: 13, color: kv.text2),
            ),
            const Spacer(),
            _DeleteButton(onPressed: cubit.deleteSelected),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, ms) in const [-10, -1, 1, 10].indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _NudgeButton(
                  deltaMs: ms,
                  onPressed: () => cubit.nudgeSelected(ms),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        KvSegmented<BeatType>(
          semanticLabel: 'Beat type',
          options: [for (final t in options) (t, beatTypeLabel(t))],
          value: beat.type,
          onChanged: cubit.setSelectedType,
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.deltaMs, required this.onPressed});

  final int deltaMs;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final left = deltaMs < 0;
    final amount = deltaMs.abs();
    final icon = KvIcon(
      left ? KvIcons.chevronLeft : KvIcons.chevronRight,
      size: 18,
      color: kv.volt,
    );
    return Semantics(
      button: true,
      label:
          'Nudge ${left ? 'left' : 'right'} $amount '
          'millisecond${amount == 1 ? '' : 's'}',
      child: Material(
        color: kv.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kv.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (left) icon,
                if (left) const SizedBox(width: 4),
                Text(
                  '$amount',
                  style: KvText.mono(
                    size: 15,
                    weight: FontWeight.w700,
                    color: kv.text1,
                  ),
                ),
                if (!left) const SizedBox(width: 4),
                if (!left) icon,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Semantics(
      button: true,
      label: 'Delete beat',
      child: Material(
        color: kv.error.withValues(alpha: 0.1),
        shape: StadiumBorder(
          side: BorderSide(color: kv.error.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KvIcon(KvIcons.trash, size: 16, color: kv.error),
                const SizedBox(width: 6),
                Text(
                  'Delete',
                  style: KvText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: kv.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
