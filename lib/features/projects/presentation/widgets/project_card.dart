import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../import/presentation/widgets/library_track_sheet.dart'
    show formatDuration;
import '../../domain/entities/project_summary.dart';
import 'edited_label.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.summary,
    required this.now,
    required this.onTap,
    required this.onLongPress,
  });

  final ProjectSummary summary;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static String _formatBpm(double bpm) =>
      bpm == bpm.roundToDouble() ? '${bpm.round()}' : bpm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final hasBeats = summary.beatCount > 0;
    final bpmLabel = summary.bpm == null
        ? '– BPM'
        : '${_formatBpm(summary.bpm!)} BPM';

    return Semantics(
      button: true,
      label: '${summary.title}, $bpmLabel',
      child: Material(
        color: kv.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: kv.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KvText.ui(
                              size: 17,
                              weight: FontWeight.w600,
                              color: kv.text1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text.rich(
                            TextSpan(
                              children: [
                                if (hasBeats) ...[
                                  TextSpan(
                                    text: '${summary.beatCount}',
                                    style: KvText.mono(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: kv.volt,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' beats',
                                    style: KvText.ui(size: 13, color: kv.text2),
                                  ),
                                ] else
                                  TextSpan(
                                    text: 'no beats yet',
                                    style: KvText.ui(size: 13, color: kv.text2),
                                  ),
                                TextSpan(
                                  text: '  ·  ',
                                  style: KvText.ui(size: 13, color: kv.text2),
                                ),
                                TextSpan(
                                  text: bpmLabel,
                                  style: KvText.mono(size: 13, color: kv.text2),
                                ),
                                TextSpan(
                                  text: '  ·  ',
                                  style: KvText.ui(size: 13, color: kv.text2),
                                ),
                                TextSpan(
                                  text: formatDuration(summary.durationMs),
                                  style: KvText.mono(size: 13, color: kv.text2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        editedLabel(summary.updatedAt, now),
                        style: KvText.ui(size: 12, color: kv.text2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: hasBeats ? 36 : 30,
                  child: CustomPaint(
                    painter: ProjectMiniWaveformPainter(
                      thumbnail: summary.thumbnail,
                      hasBeats: hasBeats,
                      barColor: kv.waveUnplayed,
                      tickColor: kv.volt,
                    ),
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

class ProjectMiniWaveformPainter extends CustomPainter {
  const ProjectMiniWaveformPainter({
    required this.thumbnail,
    required this.hasBeats,
    required this.barColor,
    required this.tickColor,
  });

  final List<int> thumbnail;
  final bool hasBeats;
  final Color barColor;
  final Color tickColor;

  static const _waveHeight = 30.0;
  static const _tickCount = 33; // 32 intervals, every 4th is a major tick

  @override
  void paint(Canvas canvas, Size size) {
    final count = thumbnail.isEmpty ? 64 : thumbnail.length;
    final barPaint = Paint()..color = barColor;
    final bars = Path();
    const barW = 2.0;

    for (var i = 0; i < count; i++) {
      final t = count > 1 ? i / (count - 1) : 0.5;
      final x = t * (size.width - barW);
      final raw = thumbnail.isEmpty ? 24 : thumbnail[i].clamp(0, 255);
      final h = math.max(3.0, (raw / 255.0) * (_waveHeight - 2));
      final y = (_waveHeight - h) / 2;
      bars.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, h),
          const Radius.circular(1),
        ),
      );
    }
    canvas.drawPath(bars, barPaint);

    if (!hasBeats) return;

    final majorPaint = Paint()..color = tickColor;
    final minorPaint = Paint()..color = tickColor.withValues(alpha: 0.6);
    for (var i = 0; i < _tickCount; i++) {
      final major = i % 4 == 0;
      final w = major ? 2.0 : 1.0;
      final h = major ? 4.0 : 3.0;
      final x = (i / (_tickCount - 1)) * (size.width - w);
      canvas.drawRect(
        Rect.fromLTWH(x, _waveHeight + 2, w, h),
        major ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ProjectMiniWaveformPainter old) =>
      old.thumbnail != thumbnail ||
      old.hasBeats != hasBeats ||
      old.barColor != barColor ||
      old.tickColor != tickColor;
}
