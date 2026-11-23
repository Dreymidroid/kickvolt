import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../../settings/settings.dart';
import '../../bloc/beat_editor_cubit.dart';

/// Context panel for the Tap tab (`EditorTap.png`, §7.3).
///
/// Uses [Listener.onPointerDown] (never `onTap`) so each beat is captured at
/// pointer-down via `PlayheadController.sampleNow() - latencyOffset`.
class TapPanel extends StatelessWidget {
  const TapPanel({super.key, required this.state, this.onOpenCalibration});

  final BeatEditorReady state;
  final VoidCallback? onOpenCalibration;

  Future<void> _openCalibration(BuildContext context) async {
    if (onOpenCalibration != null) {
      onOpenCalibration!();
      return;
    }
    final cubit = context.read<BeatEditorCubit>();
    await context.router.push(LatencyCalibrationRoute());
    if (context.mounted) {
      await cubit.refreshSettings();
    }
  }

  String _speedLabel(double speed) {
    if (speed == 0.75) return '.75×';
    if (speed == 0.5) return '0.5×';
    return '1×';
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final playing = state.playing;
    final showBtWarning = shouldShowBluetoothWarning(
      currentOutput: state.outputKind,
      calibratedOn: state.latencyCalibratedOn,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: playing ? (_) => cubit.tapBeat() : null,
                  child: Semantics(
                    button: true,
                    label: 'Tap to mark a beat',
                    child: Container(
                      decoration: BoxDecoration(
                        color: playing
                            ? kv.volt.withValues(alpha: 0.09)
                            : kv.surface1,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: playing
                              ? kv.volt.withValues(alpha: 0.5)
                              : kv.border,
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (playing) ...[
                            _Ring(
                              size: 210,
                              color: kv.volt.withValues(alpha: 0.18),
                              width: 1,
                            ),
                            _Ring(
                              size: 150,
                              color: kv.volt.withValues(alpha: 0.4),
                              width: 1,
                            ),
                            _Ring(
                              size: 96,
                              color: kv.volt.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ],
                          if (playing)
                            Text(
                              'TAP',
                              style: KvText.heading(
                                size: 44,
                                color: kv.volt,
                              ).copyWith(letterSpacing: 1.8),
                            )
                          else
                            Text(
                              'Press play, then tap along',
                              textAlign: TextAlign.center,
                              style: KvText.ui(
                                size: 15,
                                weight: FontWeight.w600,
                                color: kv.text2,
                              ),
                            ),
                          Positioned(
                            left: 16,
                            top: 12,
                            child: Text(
                              'Tap on every beat',
                              style: KvText.ui(
                                size: 12,
                                weight: FontWeight.w600,
                                color: kv.text2,
                              ),
                            ),
                          ),
                          if (state.tapRunBeats.isNotEmpty)
                            Positioned(
                              right: 16,
                              top: 10,
                              child: Text(
                                '+${state.tapRunBeats.length}',
                                style: KvText.mono(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: kv.volt,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 16,
                            bottom: 12,
                            child: Text(
                              playing
                                  ? 'playing at ${_speedLabel(state.speed)}'
                                  : 'speed ${_speedLabel(state.speed)}',
                              style: KvText.mono(size: 12, color: kv.text2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Separate hit region so tapping "lag fix" opens calibration
              // without triggering a beat tap.
              Positioned(
                right: 8,
                bottom: 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openCalibration(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(
                      'lag fix ${state.latencyOffsetMs} ms',
                      style: KvText.mono(
                        size: 12,
                        weight: FontWeight.w600,
                        color: kv.volt,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showBtWarning) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kv.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kv.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                KvIcon(KvIcons.alertCircle, size: 16, color: kv.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bluetooth adds 150–300 ms of delay. Calibrate with these headphones.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KvText.ui(size: 11, color: kv.text1),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => _openCalibration(context),
                  style: TextButton.styleFrom(
                    foregroundColor: kv.volt,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Calibrate',
                    style: KvText.ui(
                      size: 12,
                      weight: FontWeight.w700,
                      color: kv.volt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color, required this.width});

  final double size;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: width),
        ),
      ),
    );
  }
}
