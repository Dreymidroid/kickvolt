import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';
import 'timeline_painter.dart' show formatClock;

class EditorTopBar extends StatelessWidget {
  const EditorTopBar({super.key, required this.state, this.onExport});

  final BeatEditorReady state;
  final VoidCallback? onExport;

  static String _formatBpm(double bpm) =>
      bpm == bpm.roundToDouble() ? '${bpm.round()}' : bpm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final p = state.project;
    final hasBeats = p.beatCount > 0;
    final subtitle = hasBeats
        ? '${p.beatCount} ${p.beatCount == 1 ? 'beat' : 'beats'} · '
              '${p.bpm == null ? '– BPM' : '${_formatBpm(p.bpm!)} BPM'}'
        : '${formatClock(p.durationMs)} · no beats yet';

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            KvIconButton(
              icon: KvIcons.chevronLeft,
              tooltip: 'Back to projects',
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KvText.ui(
                      size: 16,
                      weight: FontWeight.w600,
                      color: kv.text1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(subtitle, style: KvText.mono(size: 12, color: kv.text2)),
                ],
              ),
            ),
            KvIconButton(
              icon: KvIcons.undo,
              tooltip: 'Undo',
              onPressed: state.undoStack.isEmpty ? null : cubit.undo,
            ),
            const SizedBox(width: 2),
            KvIconButton(
              icon: KvIcons.redo,
              tooltip: 'Redo',
              onPressed: state.redoStack.isEmpty ? null : cubit.redo,
            ),
            const SizedBox(width: 6),
            Material(
              color: hasBeats ? kv.volt : kv.surface2,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: hasBeats ? onExport : null,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Text(
                    'Export',
                    style: KvText.ui(
                      size: 15,
                      weight: FontWeight.w700,
                      color: hasBeats ? kv.onVolt : kv.text3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
