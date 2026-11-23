import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';
import 'timeline_painter.dart' show formatClock;

/// Compact list panel for the Sections tab (§7.5).
class SectionsPanel extends StatelessWidget {
  const SectionsPanel({super.key, required this.state});

  final BeatEditorReady state;

  Future<void> _showRenameDialog(
    BuildContext context,
    int index,
    String currentName,
  ) async {
    final cubit = context.read<BeatEditorCubit>();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameSectionDialog(initialName: currentName),
    );
    if (result != null && result.trim().isNotEmpty) {
      cubit.renameSection(index, result);
    }
  }

  Future<void> _showColourDialog(
    BuildContext context,
    int index,
    int currentColorArgb,
  ) async {
    final cubit = context.read<BeatEditorCubit>();
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Section colour'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final preset in sectionPresets)
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(preset.colorArgb),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(preset.colorArgb),
                        shape: BoxShape.circle,
                        border: preset.colorArgb == currentColorArgb
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(preset.name, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      cubit.recolourSection(index, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final sections = state.project.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sections (${sections.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KvText.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: kv.text1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: kv.surface2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: kv.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: cubit.splitSectionAtPlayhead,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KvIcon(KvIcons.plus, size: 15, color: kv.volt),
                      const SizedBox(width: 6),
                      Text(
                        'Split at playhead',
                        style: KvText.ui(
                          size: 13,
                          weight: FontWeight.w600,
                          color: kv.text1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: sections.isEmpty
              ? Center(
                  child: Text(
                    'No sections yet. Tap “Split at playhead” to create one.',
                    textAlign: TextAlign.center,
                    style: KvText.ui(size: 13, color: kv.text2),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final sec = sections[index];
                    final startLabel = formatClock(
                      state.project.sampleToMs(sec.startSample),
                    );
                    final endLabel = formatClock(
                      state.project.sampleToMs(sec.endSample),
                    );
                    return Material(
                      color: kv.surface1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: kv.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => cubit.seekTo(sec.startSample),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showColourDialog(
                                  context,
                                  index,
                                  sec.colorArgb,
                                ),
                                child: Tooltip(
                                  message: 'Recolour section',
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Color(sec.colorArgb),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sec.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KvText.ui(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: kv.text1,
                                  ),
                                ),
                              ),
                              Text(
                                '$startLabel – $endLabel',
                                style: KvText.mono(size: 12, color: kv.text2),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () =>
                                    _showRenameDialog(context, index, sec.name),
                                style: TextButton.styleFrom(
                                  foregroundColor: kv.text2,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Rename',
                                  style: KvText.ui(size: 12, color: kv.text2),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete section',
                                onPressed: () => cubit.deleteSection(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: KvIcon(
                                  KvIcons.trash,
                                  size: 15,
                                  color: kv.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RenameSectionDialog extends StatefulWidget {
  const _RenameSectionDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameSectionDialog> createState() => _RenameSectionDialogState();
}

class _RenameSectionDialogState extends State<_RenameSectionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename section'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Section name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
