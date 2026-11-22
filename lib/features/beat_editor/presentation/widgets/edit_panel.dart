import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';

const String kAutoDetectPlaceholderMessage =
    'Beat detection arrives in the next update';

/// Context panel for the Edit tab with no marker selected.
/// When the project has 0 beats, renders the empty prompt from `EditorEmpty.png`.
class EditPanel extends StatelessWidget {
  const EditPanel({super.key, required this.state, this.onRedetect});

  final BeatEditorReady state;
  final VoidCallback? onRedetect;

  void _showDetectionPlaceholder(BuildContext context) {
    if (onRedetect != null) {
      onRedetect!();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(kAutoDetectPlaceholderMessage)),
      );
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
            onPressed: () => _showDetectionPlaceholder(context),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(value: p.beatCount, label: 'beats'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: p.strongCount, label: 'strong'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(value: p.dropCount, label: 'drops'),
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
                onPressed: () => _showDetectionPlaceholder(context),
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
