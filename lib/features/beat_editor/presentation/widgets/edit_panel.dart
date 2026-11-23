import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../beat_detection/beat_detection.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';

/// Context panel for the Edit tab with no marker selected.
/// When the project has 0 beats, renders the empty prompt from `EditorEmpty.png`.
class EditPanel extends StatelessWidget {
  const EditPanel({super.key, required this.state, this.onRedetect});

  final BeatEditorReady state;
  final VoidCallback? onRedetect;

  void _openAutoDetect(BuildContext context) {
    if (onRedetect != null) {
      onRedetect!();
      return;
    }
    context.read<BeatEditorCubit>().openAutoDetectSheet();
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final p = state.project;

    if (p.beatCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KvPrimaryButton(
            label: 'Auto-detect beats',
            icon: KvIcons.sparkle,
            height: 56,
            fontSize: 17,
            onPressed: () => _openAutoDetect(context),
          ),
          const SizedBox(height: 10),
          KvSecondaryButton(
            label: 'Tap them in while it plays',
            icon: KvIcons.tap,
            onPressed: () => cubit.selectTool(EditorTool.tap),
          ),
          const SizedBox(height: 10),
          Text(
            'You can fine-tune every beat after.',
            textAlign: TextAlign.center,
            style: KvText.ui(size: 13, color: kv.text2),
          ),
        ],
      );
    }

    final visibleIndices = visibleBeatIndices(p);
    final visibleCount = visibleIndices.length;
    var visibleStrong = 0;
    var visibleDrops = 0;
    for (final i in visibleIndices) {
      final t = p.beats[i].type;
      if (t != BeatType.beat) visibleStrong++;
      if (t == BeatType.drop) visibleDrops++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(value: visibleCount, label: 'beats'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: visibleStrong, label: 'strong'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: visibleDrops, label: 'drops'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            KvIcon(KvIcons.tap, size: 16, color: kv.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap a marker to nudge it. Long-press to add one.',
                style: KvText.ui(size: 13, color: kv.text2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KvSecondaryButton(
                label: 'Add at playhead',
                icon: KvIcons.plus,
                onPressed: cubit.addBeatAtPlayhead,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              child: KvSecondaryButton(
                label: 'Re-detect',
                icon: KvIcons.sparkle,
                onPressed: () => _openAutoDetect(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kv.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: KvText.mono(
              size: 22,
              weight: FontWeight.w700,
              color: kv.volt,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: KvText.ui(size: 12, color: kv.text2)),
        ],
      ),
    );
  }
}
