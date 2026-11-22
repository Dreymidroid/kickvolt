import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';

/// BPM, Snap, Clicks chips and the zoom readout.
class EditorChipsRow extends StatelessWidget {
  const EditorChipsRow({super.key, required this.state});

  final BeatEditorReady state;

  static String _formatBpm(double bpm) =>
      bpm == bpm.roundToDouble() ? '${bpm.round()}' : bpm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final bpm = state.project.bpm;
    final bpmLabel = bpm == null ? '– BPM' : '${_formatBpm(bpm)} BPM';

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          KvChip(label: bpmLabel, mono: true, onPressed: () {}),
          const SizedBox(width: 8),
          KvChip(
            label: 'Snap',
            icon: KvIcons.magnet,
            active: state.snap && bpm != null,
            onPressed: bpm == null ? null : cubit.toggleSnap,
          ),
          const SizedBox(width: 8),
          KvChip(
            label: 'Clicks',
            icon: KvIcons.volume,
            active: state.clicks,
            onPressed: cubit.toggleClicks,
          ),
          const Spacer(),
          KvIcon(KvIcons.zoom, size: 14, color: kv.text3),
          const SizedBox(width: 4),
          Text(
            '${_zoomLabel(state.zoom)}×',
            style: KvText.mono(size: 12, color: kv.text2),
          ),
        ],
      ),
    );
  }

  static String _zoomLabel(double z) =>
      z >= 10 || z == z.roundToDouble() ? '${z.round()}' : z.toStringAsFixed(1);
}

/// Speed segmented control, back/forward 2 s and the Play button.
class TransportBar extends StatelessWidget {
  const TransportBar({super.key, required this.state});

  final BeatEditorReady state;

  static const _speeds = [(0.5, '0.5×'), (0.75, '.75×'), (1.0, '1×')];

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 156,
            child: KvSegmented<double>(
              semanticLabel: 'Playback speed',
              options: _speeds,
              value: state.speed,
              onChanged: cubit.setSpeed,
              mono: true,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              KvIconButton(
                icon: KvIcons.back2,
                tooltip: 'Back 2 seconds',
                size: 48,
                onPressed: () => cubit.seekBy(-2000),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: state.playing ? 'Pause' : 'Play',
                child: GestureDetector(
                  onTap: cubit.togglePlay,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: kv.volt,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kv.volt.withValues(alpha: 0.45),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: KvIcon(
                      state.playing ? KvIcons.pause : KvIcons.play,
                      size: 28,
                      color: kv.onVolt,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              KvIconButton(
                icon: KvIcons.fwd2,
                tooltip: 'Forward 2 seconds',
                size: 48,
                onPressed: () => cubit.seekBy(2000),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom tool tabs: Auto, Tap, Edit, Sections, Bulk.
class ToolTabBar extends StatelessWidget {
  const ToolTabBar({super.key, required this.tool});

  final EditorTool tool;

  static const _tabs = [
    (EditorTool.auto, KvIcons.sparkle, 'Auto'),
    (EditorTool.tap, KvIcons.tap, 'Tap'),
    (EditorTool.edit, KvIcons.move, 'Edit'),
    (EditorTool.sections, KvIcons.layers, 'Sections'),
    (EditorTool.bulk, KvIcons.scissors, 'Bulk'),
  ];

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    return Container(
      decoration: BoxDecoration(
        color: kv.surface1,
        border: Border(top: BorderSide(color: kv.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (final (t, icon, label) in _tabs)
                Expanded(
                  child: _ToolTab(
                    icon: icon,
                    label: label,
                    active: t == tool,
                    onTap: () => cubit.selectTool(t),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTab extends StatelessWidget {
  const _ToolTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final KvIcons icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final fg = active ? kv.volt : kv.text2;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                Positioned(
                  top: 0,
                  child: Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: kv.volt,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [BoxShadow(color: kv.voltGlow, blurRadius: 6)],
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KvIcon(icon, size: 22, color: fg),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: KvText.ui(
                      size: 11,
                      weight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
