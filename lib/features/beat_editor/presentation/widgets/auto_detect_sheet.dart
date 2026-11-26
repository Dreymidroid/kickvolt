import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../beat_detection/beat_detection.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';

/// Bottom sheet overlay matching `EditorAutoDetect.png` / `EditorAutoDetect.html`
/// extended with M4b advanced detection rows (§6):
/// - Sensitivity slider
/// - Tempo row ("128 BPM" with ½×, Auto, 2×, and "More…" chips)
/// - Tempo changes switch ("Steady tempo" / "Tempo changes" + drift suggestion)
/// - Swing feel read-only indicator when confident
/// - Mark filter chips
/// - Live preview line ("~" in varying mode) & Detect beats button.
class AutoDetectSheet extends StatefulWidget {
  const AutoDetectSheet({super.key, required this.state});

  final BeatEditorReady state;

  @override
  State<AutoDetectSheet> createState() => _AutoDetectSheetState();
}

class _AutoDetectSheetState extends State<AutoDetectSheet> {
  bool _showMoreCandidates = false;

  static const _filterOptions = <(BeatFilter, String)>[
    (BeatFilter.every, 'Every beat'),
    (BeatFilter.strong, 'Strong beats'),
    (BeatFilter.drops, 'Drops only'),
    (BeatFilter.every2nd, 'Every 2nd'),
    (BeatFilter.every4th, 'Every 4th'),
  ];

  static const _tempoModeOptions = <(TempoMode, String)>[
    (TempoMode.steady, 'Steady tempo'),
    (TempoMode.varying, 'Tempo changes'),
  ];

  static String _sensitivityLabel(double s) {
    if (s < 0.34) return 'Fewer beats';
    if (s <= 0.66) return 'Balanced';
    return 'More beats';
  }

  static String _formatBpm(double bpm) =>
      bpm == bpm.roundToDouble() ? '${bpm.round()}' : bpm.toStringAsFixed(1);

  static bool _sameBpm(double? a, double? b) {
    if (a == null || b == null) return false;
    return (a - b).abs() <= 0.25;
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final state = widget.state;

    final previewBeats = state.previewBeats ?? state.project.beats;
    final visibleCount = visibleBeatIndicesForList(
      previewBeats,
      state.previewFilter,
    ).length;
    final bpm = state.previewBpm ?? state.project.bpm;
    final isVarying = state.previewTempoMode == TempoMode.varying;
    final bpmPrefix = isVarying ? '~' : '';
    final estimateText = state.previewSucceeded
        ? '≈ $visibleCount ${visibleCount == 1 ? 'beat' : 'beats'} · '
              '${bpm == null ? '– BPM' : '$bpmPrefix${_formatBpm(bpm)} BPM'}'
        : 'No steady beat found';

    final autoBpm = state.analysisAutoBpm ?? bpm;
    final halfBpm = autoBpm != null
        ? (autoBpm * 0.5 * 10.0).round() / 10.0
        : null;
    final doubleBpm = autoBpm != null
        ? (autoBpm * 2.0 * 10.0).round() / 10.0
        : null;
    final halfEnabled = halfBpm != null && halfBpm >= 40.0 && halfBpm <= 240.0;
    final doubleEnabled =
        doubleBpm != null && doubleBpm >= 40.0 && doubleBpm <= 240.0;

    final overrideBpm = state.previewTempoOverrideBpm;
    final isAutoActive = overrideBpm == null;
    final isHalfActive = halfEnabled && _sameBpm(overrideBpm, halfBpm);
    final isDoubleActive = doubleEnabled && _sameBpm(overrideBpm, doubleBpm);

    // Other candidates from `tempoCandidates` excluding Auto, ½× and 2×.
    final moreCandidates = <TempoCandidate>[
      for (final c in state.previewTempoCandidates)
        if (!_sameBpm(c.bpm, autoBpm) &&
            !_sameBpm(c.bpm, halfBpm) &&
            !_sameBpm(c.bpm, doubleBpm) &&
            c.bpm >= 40.0 &&
            c.bpm <= 240.0)
          c,
    ];
    final isMoreActive = !isAutoActive && !isHalfActive && !isDoubleActive;

    final displayedTempoBpm = overrideBpm ?? bpm ?? autoBpm;

    return Container(
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: kv.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                  children: [
                    Expanded(
                      child: Text(
                        'Fewer, louder beats',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KvText.ui(size: 12, color: kv.text3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'More, softer beats',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: KvText.ui(size: 12, color: kv.text3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // §6 Tempo row: "128 BPM" with chips ½×, Auto, 2×, More…
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tempo',
                      style: KvText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: kv.text1,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.retracking) ...[
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kv.volt,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Finding beats…',
                            style: KvText.ui(size: 12, color: kv.volt),
                          ),
                        ] else if (displayedTempoBpm != null)
                          Text(
                            '$bpmPrefix${_formatBpm(displayedTempoBpm)} BPM',
                            style: KvText.mono(
                              size: 14,
                              weight: FontWeight.w600,
                              color: kv.volt,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KvChip(
                      label: '½×',
                      mono: true,
                      active: isHalfActive,
                      onPressed: halfEnabled
                          ? () => cubit.setPreviewTempoOverride(halfBpm)
                          : null,
                    ),
                    KvChip(
                      label: 'Auto',
                      active: isAutoActive,
                      onPressed: () => cubit.setPreviewTempoOverride(null),
                    ),
                    KvChip(
                      label: '2×',
                      mono: true,
                      active: isDoubleActive,
                      onPressed: doubleEnabled
                          ? () => cubit.setPreviewTempoOverride(doubleBpm)
                          : null,
                    ),
                    if (moreCandidates.isNotEmpty)
                      KvChip(
                        label: 'More…',
                        active: _showMoreCandidates || isMoreActive,
                        onPressed: () => setState(
                          () => _showMoreCandidates = !_showMoreCandidates,
                        ),
                      ),
                  ],
                ),
                if ((_showMoreCandidates || isMoreActive) &&
                    moreCandidates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in moreCandidates)
                        KvChip(
                          label: 'Try ${_formatBpm(c.bpm)} BPM',
                          mono: true,
                          active: _sameBpm(overrideBpm, c.bpm),
                          onPressed: () => cubit.setPreviewTempoOverride(c.bpm),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                // §6 Tempo changes switch ("Steady tempo" / "Tempo changes")
                KvSegmented<TempoMode>(
                  semanticLabel: 'Tempo mode',
                  options: _tempoModeOptions,
                  value: state.previewTempoMode,
                  onChanged: cubit.setPreviewTempoMode,
                ),
                if (state.suggestsTempoChanges &&
                    state.previewTempoMode == TempoMode.steady) ...[
                  const SizedBox(height: 6),
                  Text(
                    'The tempo seems to drift. Try Tempo changes.',
                    style: KvText.ui(size: 12, color: kv.volt),
                  ),
                ],
                if (state.previewSwing.isSwung) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Swing feel detected — beats stay on the main pulse.',
                    style: KvText.ui(size: 12, color: kv.text2),
                  ),
                ],
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
                  children: [
                    Expanded(
                      child: Text(
                        'Preview on the waveform',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KvText.ui(size: 14, color: kv.text2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        estimateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: KvText.mono(size: 14, color: kv.text1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                KvPrimaryButton(
                  label: 'Detect beats',
                  icon: KvIcons.sparkle,
                  height: 56,
                  fontSize: 17,
                  onPressed: state.retracking ? null : cubit.commitAutoDetect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
