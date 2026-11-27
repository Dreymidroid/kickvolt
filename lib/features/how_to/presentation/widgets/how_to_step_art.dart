import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';

/// 120x78 visual diagram for each of the four steps in `HowToCapCut.html` /
/// `HowToVN.html`.
class HowToStepArt extends StatelessWidget {
  const HowToStepArt({super.key, required this.stepNumber});

  /// 1..4
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      width: 120,
      height: 78,
      decoration: BoxDecoration(
        color: kv.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kv.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _HowToStepPainter(stepNumber: stepNumber, kv: kv),
        child: stepNumber == 4
            ? Align(
                alignment: const Alignment(0.8, 0.45),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: kv.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: kv.error),
                  ),
                  alignment: Alignment.center,
                  child: KvIcon(KvIcons.volume, size: 12, color: kv.error),
                ),
              )
            : null,
      ),
    );
  }
}

class _HowToStepPainter extends CustomPainter {
  const _HowToStepPainter({required this.stepNumber, required this.kv});

  final int stepNumber;
  final KvColors kv;

  static const _miniBars = <double>[
    0.25,
    0.30,
    0.80,
    0.65,
    0.48,
    0.40,
    0.47,
    0.92,
    0.62,
    0.52,
    0.36,
    0.35,
    0.80,
    0.65,
    0.52,
    0.36,
    0.84,
    0.76,
    0.66,
    0.52,
    0.42,
    0.82,
    0.68,
    0.54,
    0.43,
    0.30,
    0.82,
    0.60,
    0.49,
    0.34,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    switch (stepNumber) {
      case 1:
        _paintPlus(canvas, const Offset(11, 25), kv.volt);
        _paintPlus(canvas, const Offset(11, 55), kv.volt);
        _paintSongClip(canvas, const Rect.fromLTWH(22, 14, 90, 22));
        _paintGuideClip(canvas, const Rect.fromLTWH(22, 44, 90, 22), alpha: 1);
      case 2:
        _paintSongClip(canvas, const Rect.fromLTWH(8, 18, 104, 22));
        _paintGuideClip(canvas, const Rect.fromLTWH(8, 46, 104, 22), alpha: 1);
        canvas.drawRect(
          const Rect.fromLTWH(8, 6, 1.5, 66),
          Paint()..color = kv.text1,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 2, 24, 12),
            const Radius.circular(6),
          ),
          Paint()..color = kv.text1,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '0:00',
            style: KvText.mono(
              size: 8,
              weight: FontWeight.w700,
              color: kv.onVolt,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(14 - tp.width / 2, 8 - tp.height / 2));
      case 3:
        _paintSongClip(canvas, const Rect.fromLTWH(8, 8, 104, 22));
        const guideRect = Rect.fromLTWH(8, 36, 104, 22);
        _paintGuideClip(canvas, guideRect, alpha: 1, highlightBorder: true);
        _paintBeatDots(canvas, guideRect, y: 66, alpha: 1);
      case 4:
        _paintSongClip(canvas, const Rect.fromLTWH(8, 12, 104, 22));
        const guideRect = Rect.fromLTWH(8, 40, 104, 22);
        _paintGuideClip(canvas, guideRect, alpha: 0.45);
        _paintBeatDots(canvas, guideRect, y: 69, alpha: 0.45);
    }
  }

  void _paintPlus(Canvas canvas, Offset center, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(-4.5, 0), center.translate(4.5, 0), p);
    canvas.drawLine(center.translate(0, -4.5), center.translate(0, 4.5), p);
  }

  void _paintSongClip(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = kv.surface3,
    );
    final step = rect.width / _miniBars.length;
    final paint = Paint()..color = kv.waveOverview;
    for (var i = 0; i < _miniBars.length; i++) {
      final h = _miniBars[i] * (rect.height - 4);
      final x = rect.left + i * step + 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + 1, rect.center.dy),
            width: 2,
            height: h,
          ),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  void _paintGuideClip(
    Canvas canvas,
    Rect rect, {
    required double alpha,
    bool highlightBorder = false,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(
      rrect,
      Paint()..color = kv.surface3.withValues(alpha: alpha),
    );
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      Paint()
        ..color = kv.volt.withValues(alpha: 0.3 * alpha)
        ..strokeWidth = 1,
    );
    final spikePaint = Paint()
      ..color = kv.volt.withValues(alpha: alpha)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const count = 7;
    for (var i = 0; i < count; i++) {
      final x = rect.left + 8 + i * ((rect.width - 16) / (count - 1));
      canvas.drawLine(
        Offset(x, rect.top + 4),
        Offset(x, rect.bottom - 4),
        spikePaint,
      );
    }
    if (highlightBorder) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = kv.volt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintBeatDots(
    Canvas canvas,
    Rect guideRect, {
    required double y,
    required double alpha,
  }) {
    final dotPaint = Paint()
      ..color = const Color(0xFFF2C94C).withValues(alpha: alpha);
    const count = 7;
    for (var i = 0; i < count; i++) {
      final x = guideRect.left + 8 + i * ((guideRect.width - 16) / (count - 1));
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_HowToStepPainter old) =>
      old.stepNumber != stepNumber || old.kv != kv;
}
