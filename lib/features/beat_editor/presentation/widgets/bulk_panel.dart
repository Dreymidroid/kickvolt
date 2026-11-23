import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';
import 'timeline_painter.dart' show formatClock;

/// Context panel for the Bulk tab (`EditorBulk.png`, §7.4).
class BulkPanel extends StatelessWidget {
  const BulkPanel({super.key, required this.state});

  final BeatEditorReady state;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final start = state.bulkRangeStart ?? 0;
    final end = state.bulkRangeEnd ?? 0;
    final rangeCount = state.project.beats
        .where((b) => b.sample >= start && b.sample <= end)
        .length;
    final startClock = formatClock(
      state.project.sampleToMs(start),
      millis: true,
    );
    final endClock = formatClock(state.project.sampleToMs(end), millis: true);
    final hasBpm = state.project.bpm != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Range card: Clear range (+ secondary Snap to grid when BPM is set).
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
            color: kv.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kv.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Range · $rangeCount ${rangeCount == 1 ? 'beat' : 'beats'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KvText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: kv.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startClock – $endClock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KvText.mono(size: 11, color: kv.text2),
                    ),
                  ],
                ),
              ),
              if (hasBpm) ...[
                _CompactActionButton(
                  label: 'Snap',
                  tooltip: 'Snap to grid',
                  bg: kv.surface2,
                  border: kv.border,
                  fg: kv.text1,
                  onPressed: rangeCount > 0 ? cubit.snapBulkRange : null,
                ),
                const SizedBox(width: 6),
              ],
              _CompactActionButton(
                label: 'Clear range',
                icon: KvIcons.trash,
                bg: kv.error.withValues(alpha: 0.1),
                border: kv.error.withValues(alpha: 0.35),
                fg: kv.error,
                onPressed: rangeCount > 0 ? cubit.clearBulkRange : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Shift all beats card.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
            color: kv.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kv.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Shift all beats',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KvText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: kv.text1,
                  ),
                ),
              ),
              _ShiftStepperButton(
                label: 'Shift earlier',
                isPlus: false,
                onStep: (step) => cubit.adjustBulkShiftMs(-step),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  _formatShift(state.bulkShiftMs),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: KvText.mono(
                    size: 13,
                    weight: FontWeight.w700,
                    color: kv.volt,
                  ),
                ),
              ),
              _ShiftStepperButton(
                label: 'Shift later',
                isPlus: true,
                onStep: (step) => cubit.adjustBulkShiftMs(step),
              ),
              const SizedBox(width: 6),
              _CompactActionButton(
                label: 'Apply',
                bg: state.bulkShiftMs != 0 ? kv.volt : kv.surface2,
                border: state.bulkShiftMs != 0 ? kv.volt : kv.border,
                fg: state.bulkShiftMs != 0 ? kv.onVolt : kv.text3,
                onPressed: state.bulkShiftMs != 0 ? cubit.applyBulkShift : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag the red handles to change the range.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KvText.ui(size: 13, color: kv.text2),
        ),
      ],
    );
  }

  static String _formatShift(int ms) {
    if (ms < 0) return '−${ms.abs()} ms';
    if (ms > 0) return '+$ms ms';
    return '0 ms';
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
    required this.onPressed,
    this.icon,
    this.tooltip,
  });

  final String label;
  final KvIcons? icon;
  final String? tooltip;
  final Color bg;
  final Color border;
  final Color fg;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final btn = Semantics(
      button: true,
      label: tooltip ?? label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    KvIcon(icon!, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: KvText.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _ShiftStepperButton extends StatefulWidget {
  const _ShiftStepperButton({
    required this.label,
    required this.isPlus,
    required this.onStep,
  });

  final String label;
  final bool isPlus;
  final void Function(int stepMs) onStep;

  @override
  State<_ShiftStepperButton> createState() => _ShiftStepperButtonState();
}

class _ShiftStepperButtonState extends State<_ShiftStepperButton> {
  Timer? _repeatTimer;
  int _ticks = 0;

  void _startRepeat() {
    _ticks = 0;
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      _ticks++;
      // Step by 1 ms initially, accelerating to 10 ms after holding ~0.5 s.
      widget.onStep(_ticks >= 6 ? 10 : 1);
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: widget.label,
      child: GestureDetector(
        onLongPressStart: (_) => _startRepeat(),
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: Material(
          color: kv.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: kv.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onStep(1),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Text(
                  widget.isPlus ? '+' : '−',
                  style: KvText.mono(
                    size: 18,
                    weight: FontWeight.w700,
                    color: kv.text1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
