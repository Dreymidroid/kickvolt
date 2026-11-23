import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../beat_detection/beat_detection.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';

/// Bottom sheet overlay matching `EditorAutoDetect.png` / `EditorAutoDetect.html`.
///
/// Moving the sensitivity slider or filter chips previews immediately on the
/// waveform from the cached [BeatAnalysis] without spawning an isolate or
/// saving. Tapping "Detect beats" commits through the editor's undoable path.
class AutoDetectSheet extends StatelessWidget {
  const AutoDetectSheet({super.key, required this.state});

  final BeatEditorReady state;

  static const _filterOptions = <(BeatFilter, String)>[
    (BeatFilter.every, 'Every beat'),
    (BeatFilter.strong, 'Strong beats'),
    (BeatFilter.drops, 'Drops only'),
    (BeatFilter.every2nd, 'Every 2nd'),
    (BeatFilter.every4th, 'Every 4th'),
  ];

  static String _sensitivityLabel(double s) {
    if (s < 0.34) return 'Fewer beats';
    if (s <= 0.66) return 'Balanced';
    return 'More beats';
  }

  static String _formatBpm(double bpm) =>
      bpm == bpm.roundToDouble() ? '${bpm.round()}' : bpm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();

    final previewBeats = state.previewBeats ?? state.project.beats;
    final visibleCount = visibleBeatIndicesForList(
      previewBeats,
      state.previewFilter,
    ).length;
    final bpm = state.previewBpm ?? state.project.bpm;
    final estimateText = state.previewSucceeded
        ? '≈ $visibleCount ${visibleCount == 1 ? 'beat' : 'beats'} · '
              '${bpm == null ? '– BPM' : '${_formatBpm(bpm)} BPM'}'
        : 'No steady beat found';

    return Container(
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: kv.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: kv.surface3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Auto-detect', style: KvText.heading(size: 22)),
                  KvIconButton(
                    icon: KvIcons.close,
                    tooltip: 'Close',
                    color: kv.text2,
                    onPressed: cubit.closeSheet,
                  ),
                ],
              ),
              if (state.analyzing) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: state.analysisProgress > 0
                      ? state.analysisProgress
                      : null,
                  color: kv.volt,
                  backgroundColor: kv.surface3,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
                const SizedBox(height: 12),
                Text(
                  'Analyzing audio… ${(state.analysisProgress * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: KvText.ui(size: 14, color: kv.text2),
                ),
                const SizedBox(height: 18),
                KvSecondaryButton(
                  label: 'Cancel',
                  onPressed: cubit.cancelAnalysis,
                ),
              ] else ...[
                const SizedBox(height: 8),
                // Sensitivity header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sensitivity',
                      style: KvText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: kv.text1,
                      ),
                    ),
                    Text(
                      _sensitivityLabel(state.previewSensitivity),
                      style: KvText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: kv.volt,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kv.volt,
                    inactiveTrackColor: kv.border,
                    thumbColor: kv.text1,
                    overlayColor: kv.volt.withValues(alpha: 0.28),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 13,
                    ),
                  ),
                  child: Slider(
                    value: state.previewSensitivity,
                    onChanged: cubit.setPreviewSensitivity,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fewer, louder beats',
                      style: KvText.ui(size: 12, color: kv.text3),
                    ),
                    Text(
                      'More, softer beats',
                      style: KvText.ui(size: 12, color: kv.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Mark filter chips
                Text(
                  'Mark',
                  style: KvText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: kv.text1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (filter, label) in _filterOptions)
                      KvChip(
                        label: label,
                        active: state.previewFilter == filter,
                        onPressed: () => cubit.setPreviewFilter(filter),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Live preview line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview on the waveform',
                      style: KvText.ui(size: 14, color: kv.text2),
                    ),
                    Text(
                      estimateText,
                      style: KvText.mono(size: 14, color: kv.text1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                KvPrimaryButton(
                  label: 'Detect beats',
                  icon: KvIcons.sparkle,
                  height: 56,
                  fontSize: 17,
                  onPressed: cubit.commitAutoDetect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
