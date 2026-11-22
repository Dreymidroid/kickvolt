import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/beat.dart';
import '../../domain/entities/beat_project.dart';
import '../../domain/entities/song_section.dart';

/// Pixels per second at 1× zoom. 4× (the default) = 51.2 px/s, which puts
/// beats 24 px apart at 128 BPM, as in the design.
const double kPxPerSecondAt1x = 12.8;

String formatClock(int ms, {bool millis = false}) {
  final m = ms ~/ 60000;
  final s = (ms ~/ 1000) % 60;
  final base = '$m:${s.toString().padLeft(2, '0')}';
  return millis ? '$base.${(ms % 1000).toString().padLeft(3, '0')}' : base;
}

/// Ruler, section tints + labels, waveform, beat markers and the fixed
/// centre playhead. Vertical offsets mirror screens/EditorDetected.html
/// (this widget starts at y=144 of the 844 frame).
class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.project,
    required this.playheadMs,
    required this.zoom,
    required this.colors,
    this.selectedIndex,
  });

  final BeatProject project;
  final int playheadMs;
  final double zoom;
  final KvColors colors;
  final int? selectedIndex;

  static const _rulerLabelTop = 8.0;
  static const _rulerTickTop = 22.0;
  static const _sectionLabelTop = 32.0;
  static const _sectionDividerTop = 30.0;
  static const _tintTop = 52.0;
  static const _dropFlagTop = 54.0;
  static const _pillTop = 55.0;
  static const _dotTop = 66.0;
  static const _beatLineTop = 74.0;
  static const _strongLineTop = 76.0;
  static const _waveTop = 78.0;
  static const _playheadTop = 6.0;
  static const _bubbleTop = -2.0;

  static const _barWidth = 2.0;
  static const _barStep = 3.0;

  static const _selectedLineTop = 72.0;
  static const _ringCenterY = 65.0;
  static const _ringRadius = 15.0;

  double get pxPerMs => zoom * kPxPerSecondAt1x / 1000;

  /// Index of the marker under a tap at [dx], or null if none is within
  /// [slopPx]. Taps above the section tint (ruler, labels) are ignored.
  static int? beatAt({
    required BeatProject project,
    required int playheadMs,
    required double zoom,
    required double dx,
    required double dy,
    required double width,
    // Under half the 24 px beat spacing at 4×, so empty space between
    // markers stays tappable (deselects). Zoom in for finer targets.
    double slopPx = 10,
  }) {
    if (dy < _tintTop) return null;
    final pxPerMs = zoom * kPxPerSecondAt1x / 1000;
    final t = playheadMs + (dx - width / 2) / pxPerMs;
    final beats = project.beats;
    final hi = _lowerBound(beats, t);
    int? best;
    var bestPx = slopPx;
    for (final i in [hi - 1, hi]) {
      if (i < 0 || i >= beats.length) continue;
      final px = (beats[i].timeMs - t).abs() * pxPerMs;
      if (px <= bestPx) {
        best = i;
        bestPx = px;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    double xOf(num ms) => cx + (ms - playheadMs) * pxPerMs;
    final visibleFrom = playheadMs - cx / pxPerMs;
    final visibleTo = playheadMs + cx / pxPerMs;

    _paintSections(canvas, size, xOf, visibleFrom, visibleTo);
    _paintRuler(canvas, size, xOf, visibleFrom, visibleTo);
    _paintWaveform(canvas, size, cx, visibleFrom, visibleTo);
    _paintBeats(canvas, size, xOf, visibleFrom, visibleTo);
    _paintPlayhead(canvas, size, cx);
  }

  void _paintSections(
    Canvas canvas,
    Size size,
    double Function(num) xOf,
    double from,
    double to,
  ) {
    for (final s in project.sections) {
      if (s.endMs < from || s.startMs > to) continue;
      final color = colors.section(s.kind);
      final l = xOf(s.startMs).clamp(0.0, size.width);
      final r = xOf(s.endMs).clamp(0.0, size.width);
      canvas.drawRect(
        Rect.fromLTRB(l, _tintTop, r, size.height),
        Paint()..color = color.withValues(alpha: 0.07),
      );

      if (s.startMs > 0 && s.startMs >= from) {
        _dashedVLine(
          canvas,
          xOf(s.startMs).roundToDouble() + 0.5,
          _sectionDividerTop,
          size.height,
          Paint()
            ..color = color.withValues(alpha: 0.6)
            ..strokeWidth = 1,
        );
      }

      final tp = _text(
        s.kind.name.toUpperCase(),
        KvText.ui(
          size: 11,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 11 * 0.08,
        ),
      );
      final w = tp.width + 16;
      var left = math.max(xOf(s.startMs), 0.0) + 6;
      // Stick to the left edge, but get pushed out by the next section.
      left = math.min(left, xOf(s.endMs) - w - 6);
      if (left + w < 0 || left > size.width) continue;
      final rect = RRect.fromLTRBR(
        left,
        _sectionLabelTop,
        left + w,
        _sectionLabelTop + 18,
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.18));
      tp.paint(
        canvas,
        Offset(left + 8, _sectionLabelTop + (18 - tp.height) / 2),
      );
    }
  }

  void _paintRuler(
    Canvas canvas,
    Size size,
    double Function(num) xOf,
    double from,
    double to,
  ) {
    const steps = [1, 2, 5, 10, 15, 30, 60];
    final pxPerSec = pxPerMs * 1000;
    final step = steps.firstWhere((s) => s * pxPerSec >= 45, orElse: () => 120);
    final tick = Paint()..color = colors.text3;
    final style = KvText.mono(size: 11, color: colors.text3);
    var sec = ((from / 1000) / step).floor() * step;
    while (sec * 1000 <= to + 1000) {
      if (sec >= 0) {
        final x = xOf(sec * 1000);
        canvas.drawRect(Rect.fromLTWH(x, _rulerTickTop, 1, 8), tick);
        _text(
          formatClock(sec * 1000),
          style,
        ).paint(canvas, Offset(x + 4, _rulerLabelTop));
      }
      sec += step;
    }
  }

  void _paintWaveform(
    Canvas canvas,
    Size size,
    double cx,
    double from,
    double to,
  ) {
    final waveH = size.height - _waveTop;
    final mid = _waveTop + waveH / 2;
    final barMs = _barStep / pxPerMs;
    final played = Path();
    final unplayed = Path();
    final first = math.max(0, (from / barMs).floor());
    final last = math.min(
      (project.durationMs / barMs).floor(),
      (to / barMs).ceil(),
    );
    for (var k = first; k <= last; k++) {
      final t = k * barMs;
      final x = cx + (t - playheadMs) * pxPerMs;
      final peak = project.peakBetween(t, t + barMs);
      final h = math.max(2.0, peak * waveH * 0.97);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, mid - h / 2, _barWidth, h),
        const Radius.circular(1),
      );
      (t < playheadMs ? played : unplayed).addRRect(r);
    }
    final glow = Paint()
      ..color = colors.waveGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas
      ..drawPath(played, glow)
      ..drawPath(unplayed, glow)
      ..drawPath(played, Paint()..color = colors.wavePlayed)
      ..drawPath(unplayed, Paint()..color = colors.waveUnplayed);
  }

  void _paintBeats(
    Canvas canvas,
    Size size,
    double Function(num) xOf,
    double from,
    double to,
  ) {
    final beats = project.beats;
    final pad = 40 / pxPerMs;
    var i = _lowerBound(beats, from - pad);
    final glow = Paint()
      ..color = colors.voltGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final solid = Paint()..color = colors.volt;

    double? selectedX;
    for (; i < beats.length && beats[i].timeMs <= to + pad; i++) {
      final b = beats[i];
      final x = xOf(b.timeMs);
      if (i == selectedIndex) {
        selectedX = x; // drawn last so nothing covers it
        continue;
      }
      switch (b.type) {
        case BeatType.beat:
          canvas
            ..drawRect(
              Rect.fromLTRB(x - 0.75, _beatLineTop, x + 0.75, size.height),
              Paint()..color = colors.volt.withValues(alpha: 0.5),
            )
            ..drawCircle(
              Offset(x, _dotTop + 3),
              3,
              Paint()..color = colors.volt.withValues(alpha: 0.75),
            );
        case BeatType.strong:
          final line = Rect.fromLTRB(
            x - 1.25,
            _strongLineTop,
            x + 1.25,
            size.height,
          );
          final tp = _text(
            '${i + 1}',
            KvText.mono(
              size: 11,
              weight: FontWeight.w700,
              color: colors.onVolt,
            ),
          );
          final w = math.max(26.0, tp.width + 12);
          final pill = RRect.fromLTRBR(
            x - w / 2,
            _pillTop,
            x + w / 2,
            _pillTop + 20,
            const Radius.circular(10),
          );
          canvas
            ..drawRect(line, glow)
            ..drawRRect(pill, glow)
            ..drawRect(line, solid)
            ..drawRRect(pill, solid);
          tp.paint(
            canvas,
            Offset(x - tp.width / 2, _pillTop + (20 - tp.height) / 2),
          );
        case BeatType.drop:
          final line = Rect.fromLTRB(
            x - 1.5,
            _strongLineTop,
            x + 1.5,
            size.height,
          );
          final flag = RRect.fromLTRBR(
            x - 24,
            _dropFlagTop,
            x + 24,
            _dropFlagTop + 22,
            const Radius.circular(11),
          );
          canvas
            ..drawRect(line, glow)
            ..drawRRect(flag, glow)
            ..drawRect(line, solid)
            ..drawRRect(flag, solid);
          final tp = _text(
            'DROP',
            KvText.ui(
              size: 10,
              weight: FontWeight.w800,
              color: colors.onVolt,
              letterSpacing: 0.6,
            ),
          );
          final contentW = 12 + 2 + tp.width;
          final left = x - contentW / 2;
          _drawBolt(canvas, Offset(left, _dropFlagTop + 5), 12);
          tp.paint(
            canvas,
            Offset(left + 14, _dropFlagTop + (22 - tp.height) / 2),
          );
      }
    }
    if (selectedX != null) {
      _paintSelected(canvas, size, selectedX, selectedIndex! + 1);
    }
  }

  void _drawBolt(Canvas canvas, Offset origin, double size) {
    final s = size / 24;
    final p = Path()
      ..moveTo(13 * s, 2 * s)
      ..lineTo(3 * s, 14 * s)
      ..lineTo(12 * s, 14 * s)
      ..lineTo(11 * s, 22 * s)
      ..lineTo(21 * s, 10 * s)
      ..lineTo(12 * s, 10 * s)
      ..close();
    canvas.drawPath(p.shift(origin), Paint()..color = colors.onVolt);
  }

  void _paintSelected(Canvas canvas, Size size, double x, int number) {
    final line = Rect.fromLTRB(x - 1.5, _selectedLineTop, x + 1.5, size.height);
    final center = Offset(x, _ringCenterY);
    canvas
      ..drawRect(
        line,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      )
      ..drawRect(line, Paint()..color = colors.text1)
      ..drawCircle(
        center,
        _ringRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      )
      ..drawCircle(
        center,
        _ringRadius + 4,
        Paint()..color = colors.text1.withValues(alpha: 0.25),
      )
      ..drawCircle(center, _ringRadius, Paint()..color = colors.text1);
    final tp = _text(
      '$number',
      KvText.mono(size: 12, weight: FontWeight.w700, color: colors.onVolt),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintPlayhead(Canvas canvas, Size size, double cx) {
    final line = Rect.fromLTRB(cx - 1, _playheadTop, cx + 1, size.height);
    canvas
      ..drawRect(
        line.inflate(1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawRect(line, Paint()..color = colors.text1);

    final bubble = RRect.fromLTRBR(
      cx - 38,
      _bubbleTop,
      cx + 38,
      _bubbleTop + 22,
      const Radius.circular(11),
    );
    canvas.drawRRect(bubble, Paint()..color = colors.text1);
    final tp = _text(
      formatClock(playheadMs, millis: true),
      KvText.mono(size: 11, weight: FontWeight.w700, color: colors.onVolt),
    );
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, _bubbleTop + (22 - tp.height) / 2),
    );
  }

  static int _lowerBound(List<Beat> beats, double ms) {
    var lo = 0;
    var hi = beats.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (beats[mid].timeMs < ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static void _dashedVLine(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Paint paint,
  ) {
    for (var y = top; y < bottom; y += 6) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3, bottom)), paint);
    }
  }

  static TextPainter _text(String s, TextStyle style) => TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: ui.TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(TimelinePainter old) =>
      old.project != project ||
      old.playheadMs != playheadMs ||
      old.zoom != zoom ||
      old.selectedIndex != selectedIndex ||
      old.colors != colors;
}

/// Whole-song strip: section tints, mini waveform and the viewport box.
class OverviewPainter extends CustomPainter {
  OverviewPainter({
    required this.project,
    required this.playheadMs,
    required this.visibleMs,
    required this.colors,
  });

  final BeatProject project;
  final int playheadMs;
  final double visibleMs;
  final KvColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final d = project.durationMs.toDouble();
    double xOf(num ms) => ms / d * size.width;
    final strip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas
      ..save()
      ..clipRRect(strip)
      ..drawRRect(strip, Paint()..color = colors.surface1);

    for (final SongSection s in project.sections) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(s.startMs), 0, xOf(s.endMs), size.height),
        Paint()..color = colors.section(s.kind).withValues(alpha: 0.14),
      );
    }

    final bars = Path();
    final maxH = size.height - 1;
    for (var x = 0.0; x < size.width; x += 2) {
      final t0 = x / size.width * d;
      final t1 = (x + 2) / size.width * d;
      final h = math.max(
        2.0,
        math.min(1.0, project.meanBetween(t0, t1) * 1.45) * maxH,
      );
      bars.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, 1, h),
          const Radius.circular(1),
        ),
      );
    }
    canvas
      ..drawPath(bars, Paint()..color = colors.waveOverview)
      ..restore();

    final w = math.max(20.0, xOf(visibleMs));
    final left = (xOf(playheadMs) - w / 2).clamp(0.0, size.width - w);
    final box = RRect.fromLTRBR(
      left,
      -1,
      left + w,
      size.height - 1,
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(
        box,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawRRect(
        box.deflate(0.75),
        Paint()
          ..color = colors.text1
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(OverviewPainter old) =>
      old.project != project ||
      old.playheadMs != playheadMs ||
      old.visibleMs != visibleMs ||
      old.colors != colors;
}
