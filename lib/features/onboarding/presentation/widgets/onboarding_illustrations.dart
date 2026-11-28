import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';

/// Shared synthetic 8-transient bar heights used by both onboarding cards so
/// the illustrations are crisp and deterministic at any width.
const List<double> _kDemoWaveHeights = <double>[
  0.16,
  0.14,
  0.19,
  0.15,
  0.82,
  0.78,
  0.52,
  0.39,
  0.25,
  0.24,
  0.32,
  0.30,
  0.20,
  0.27,
  0.29,
  0.24,
  0.22,
  0.88,
  0.63,
  0.55,
  0.42,
  0.31,
  0.23,
  0.16,
  0.24,
  0.32,
  0.16,
  0.19,
  0.23,
  0.13,
  0.98,
  0.88,
  0.62,
  0.41,
  0.44,
  0.25,
  0.35,
  0.19,
  0.16,
  0.15,
  0.16,
  0.31,
  0.20,
  0.20,
  0.76,
  0.45,
  0.32,
  0.41,
  0.23,
  0.24,
  0.25,
  0.32,
  0.14,
  0.14,
  0.30,
  0.29,
  0.22,
  1.00,
  0.73,
  0.55,
  0.43,
  0.43,
  0.27,
  0.23,
  0.19,
  0.27,
  0.22,
  0.31,
  0.21,
  0.20,
  0.74,
  0.64,
  0.48,
  0.47,
  0.38,
  0.35,
  0.22,
  0.22,
  0.26,
  0.31,
  0.17,
  0.30,
  0.22,
  0.31,
  0.92,
  0.75,
  0.60,
  0.34,
  0.28,
  0.35,
  0.28,
  0.27,
  0.25,
  0.24,
  0.31,
  0.26,
  0.18,
  0.84,
  0.54,
  0.34,
  0.28,
  0.40,
  0.34,
  0.16,
  0.32,
  0.15,
  0.27,
  0.19,
];

/// Indices of the 8 real beats in [_kDemoWaveHeights].
const List<int> _kBeatBarIndices = <int>[4, 17, 30, 44, 57, 70, 84, 97];

/// Onboarding screen 1 (`Main.html` / `Main.png`) comparison card:
/// "EDITOR AUTO-BEAT" (guessed/missed) vs "MARKED IN KICKVOLT".
class ProblemComparisonCard extends StatelessWidget {
  const ProblemComparisonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kv.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'EDITOR AUTO-BEAT',
            style: KvText.ui(
              size: 12,
              weight: FontWeight.w600,
              letterSpacing: 0.96,
              color: kv.text3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: CustomPaint(
              painter: _EditorGuessedWavePainter(
                waveColor: kv.waveOverview,
                guessedColor: kv.text2,
                tickColor: kv.text3,
                missedColor: kv.error,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: kv.text2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('guessed', style: KvText.ui(size: 12, color: kv.text2)),
              const SizedBox(width: 14),
              SizedBox(
                width: 10,
                height: 10,
                child: CustomPaint(
                  painter: _DashedCirclePainter(color: kv.error),
                ),
              ),
              const SizedBox(width: 6),
              Text('missed', style: KvText.ui(size: 12, color: kv.text2)),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: kv.border),
          const SizedBox(height: 14),
          Text(
            'MARKED IN KICKVOLT',
            style: KvText.ui(
              size: 12,
              weight: FontWeight.w600,
              letterSpacing: 0.96,
              color: kv.volt,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: CustomPaint(
              painter: _KickVoltMarkedWavePainter(
                waveColor: kv.waveOverview,
                volt: kv.volt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorGuessedWavePainter extends CustomPainter {
  const _EditorGuessedWavePainter({
    required this.waveColor,
    required this.guessedColor,
    required this.tickColor,
    required this.missedColor,
  });

  final Color waveColor;
  final Color guessedColor;
  final Color tickColor;
  final Color missedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const waveHeight = 56.0;
    _paintWaveBars(canvas, Size(size.width, waveHeight), waveColor);

    final count = _kDemoWaveHeights.length;
    double barX(int idx) => (idx + 0.5) * (size.width / count);
    const dotY = waveHeight + 13.0;

    final dotPaint = Paint()..color = guessedColor;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Guessed (some late with drift ticks) and missed beats matching Main.html.
    final guessedPlain = <int>[
      _kBeatBarIndices[0],
      _kBeatBarIndices[3],
      _kBeatBarIndices[6],
    ];
    for (final idx in guessedPlain) {
      canvas.drawCircle(Offset(barX(idx), dotY), 5, dotPaint);
    }

    final guessedLate = <int>[_kBeatBarIndices[1], _kBeatBarIndices[4]];
    for (final idx in guessedLate) {
      final trueX = barX(idx);
      final lateX = trueX + 12;
      canvas.drawLine(Offset(trueX, dotY), Offset(lateX - 4, dotY), tickPaint);
      canvas.drawCircle(Offset(lateX, dotY), 5, dotPaint);
    }

    final missed = <int>[
      _kBeatBarIndices[2],
      _kBeatBarIndices[5],
      _kBeatBarIndices[7],
    ];
    for (final idx in missed) {
      _drawDashedCircle(canvas, Offset(barX(idx), dotY), 5.5, missedColor);
    }
  }

  @override
  bool shouldRepaint(_EditorGuessedWavePainter old) =>
      old.waveColor != waveColor ||
      old.guessedColor != guessedColor ||
      old.missedColor != missedColor;
}

class _KickVoltMarkedWavePainter extends CustomPainter {
  const _KickVoltMarkedWavePainter({
    required this.waveColor,
    required this.volt,
  });

  final Color waveColor;
  final Color volt;

  @override
  void paint(Canvas canvas, Size size) {
    const waveHeight = 56.0;
    _paintWaveBars(canvas, Size(size.width, waveHeight), waveColor);

    final count = _kDemoWaveHeights.length;
    double barX(int idx) => (idx + 0.5) * (size.width / count);
    const dotY = waveHeight + 13.0;

    final glowLine = Paint()
      ..color = volt.withValues(alpha: 0.65)
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final linePaint = Paint()
      ..color = volt
      ..strokeWidth = 2;
    final glowDot = Paint()
      ..color = volt.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dotPaint = Paint()..color = volt;

    for (final idx in _kBeatBarIndices) {
      final x = barX(idx);
      canvas.drawLine(Offset(x, 2), Offset(x, dotY), glowLine);
      canvas.drawLine(Offset(x, 2), Offset(x, dotY), linePaint);
      canvas.drawCircle(Offset(x, dotY), 5, glowDot);
      canvas.drawCircle(Offset(x, dotY), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_KickVoltMarkedWavePainter old) =>
      old.waveColor != waveColor || old.volt != volt;
}

/// Onboarding screen 2 (`Onboarding2.html` / `Onboarding2.png`) beat-pack card.
/// Shows Song, Guide and Video (M7 guide video; no PRO badge, M8 §4.2).
class BeatPackIllustrationCard extends StatelessWidget {
  const BeatPackIllustrationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kv.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR BEAT PACK',
            style: KvText.ui(
              size: 12,
              weight: FontWeight.w600,
              letterSpacing: 0.96,
              color: kv.text3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  'Song',
                  style: KvText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: kv.text2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: CustomPaint(
                    painter: _SongStripPainter(waveColor: kv.waveOverview),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  'Guide',
                  style: KvText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: kv.text2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: CustomPaint(
                    painter: _GuideStripPainter(volt: kv.volt),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  'Video',
                  style: KvText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: kv.text2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    // The guide video counts beats 1, 2, 3, …; beat 3 is on
                    // its white flash frame.
                    for (var n = 1; n <= 6; n++) ...[
                      if (n > 1) const SizedBox(width: 4),
                      Expanded(
                        child: _VideoTile(number: n, flash: n == 3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.number, required this.flash});

  final int number;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: flash ? kv.text1 : const Color(0xFF000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kv.border),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: KvText.mono(
          size: 14,
          weight: FontWeight.w700,
          color: flash ? kv.background : kv.text2,
        ),
      ),
    );
  }
}

class _SongStripPainter extends CustomPainter {
  const _SongStripPainter({required this.waveColor});

  final Color waveColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWaveBars(canvas, size, waveColor, barCount: 90);
  }

  @override
  bool shouldRepaint(_SongStripPainter old) => old.waveColor != waveColor;
}

class _GuideStripPainter extends CustomPainter {
  const _GuideStripPainter({required this.volt});

  final Color volt;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = volt.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    final glow = Paint()
      ..color = volt.withValues(alpha: 0.65)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final spike = Paint()
      ..color = volt
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const spikeIndices = <int>[4, 17, 30, 44, 57, 70, 84];
    for (final idx in spikeIndices) {
      final x = (idx + 0.5) * (size.width / 90);
      canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), glow);
      canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), spike);
    }
  }

  @override
  bool shouldRepaint(_GuideStripPainter old) => old.volt != volt;
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _drawDashedCircle(
      canvas,
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      color,
    );
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

void _paintWaveBars(Canvas canvas, Size size, Color color, {int? barCount}) {
  final count = barCount ?? _kDemoWaveHeights.length;
  final step = size.width / count;
  final midY = size.height / 2;
  final paint = Paint()..color = color;
  for (var i = 0; i < count; i++) {
    final hFrac = _kDemoWaveHeights[i % _kDemoWaveHeights.length];
    final h = math.max(3.0, hFrac * (size.height - 6));
    final x = i * step + (step - 2) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x + 1, midY), width: 2, height: h),
        const Radius.circular(1),
      ),
      paint,
    );
  }
}

void _drawDashedCircle(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  const segments = 5;
  const sweep = (2 * math.pi / segments) * 0.58;
  final rect = Rect.fromCircle(center: center, radius: radius);
  for (var i = 0; i < segments; i++) {
    final start = i * (2 * math.pi / segments);
    canvas.drawArc(rect, start, sweep, false, paint);
  }
}
