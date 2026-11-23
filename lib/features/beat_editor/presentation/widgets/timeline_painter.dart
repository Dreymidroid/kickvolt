import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/audio_math/pcm_window_loader.dart';
import '../../../../core/audio_math/peaks.dart';
import '../../../../shared/shared.dart';
import '../../../beat_detection/beat_detection.dart';
import '../../../projects/projects.dart';
import '../../bloc/beat_editor_cubit.dart';

String formatClock(int ms, {bool millis = false}) {
  final safeMs = math.max(0, ms);
  final m = safeMs ~/ 60000;
  final s = (safeMs ~/ 1000) % 60;
  final base = '$m:${s.toString().padLeft(2, '0')}';
  return millis ? '$base.${(safeMs % 1000).toString().padLeft(3, '0')}' : base;
}

/// Lays out text once and reuses it across frames.
class _TextCache {
  final _cache = <String, TextPainter>{};

  TextPainter get(String key, String text, TextStyle style) {
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 400) _cache.clear();
    return _cache[key] = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }
}

/// Ruler, section tints + labels, waveform, beat markers and the fixed
/// centre playhead. Vertical offsets mirror screens/EditorDetected.html
/// (this widget starts at y=144 of the 844 frame).
///
/// Repaints from [playhead], [zoom] and [pcm] directly, so playback and
/// pinch-zoom never rebuild widgets. Nothing here allocates per bar or per
/// beat on a normal frame.
class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.project,
    required this.peaks,
    required this.playhead,
    required this.zoom,
    required this.colors,
    this.pcm,
    this.selectedIndex,
    this.beatsOverride,
    this.filterOverride,
    this.sectionsOverride,
  }) : super(repaint: Listenable.merge([playhead, zoom, ?pcm])) {
    _beatLine.color = colors.volt.withValues(alpha: 0.5);
    _farBeatLine.color = colors.volt.withValues(alpha: 0.28);
    _beatDot.color = colors.volt.withValues(alpha: 0.75);
    _glow
      ..color = colors.voltGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    _solid.color = colors.volt;
    _downbeatSolid.color = Color.lerp(colors.volt, Colors.white, 0.35)!;
    _waveGlow
      ..color = colors.waveGlow
      ..strokeWidth = _barWidth + 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    _played
      ..color = colors.wavePlayed
      ..strokeWidth = _barWidth;
    _unplayed
      ..color = colors.waveUnplayed
      ..strokeWidth = _barWidth;
    _tick.color = colors.text3;
  }

  final Project project;
  final PeakPyramid peaks;
  final ValueListenable<int> playhead;
  final ValueListenable<double> zoom;
  final PcmWindowLoader? pcm;
  final KvColors colors;
  final int? selectedIndex;
  final List<Beat>? beatsOverride;
  final BeatFilter? filterOverride;
  final List<Section>? sectionsOverride;

  List<Beat> get _effectiveBeats => beatsOverride ?? project.beats;
  BeatFilter get _effectiveFilter => filterOverride ?? project.detection.filter;
  List<Section> get _effectiveSections => sectionsOverride ?? project.sections;

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

  static const _selectedLineTop = 72.0;
  static const _ringCenterY = 65.0;
  static const _ringRadius = 15.0;

  /// Below this spacing, markers are drawn as plain lines (no pills/dots).
  static const _detailedBeatSpacingPx = 14.0;

  /// When zoomed far out, lines closer than this are skipped.
  static const _minLineGapPx = 4.0;

  final _text = _TextCache();
  final _beatLine = Paint();
  final _farBeatLine = Paint();
  final _beatDot = Paint();
  final _glow = Paint();
  final _solid = Paint();
  final _downbeatSolid = Paint();
  final _waveGlow = Paint();
  final _played = Paint();
  final _unplayed = Paint();
  final _tick = Paint();

  Float32List _mins = Float32List(0);
  Float32List _maxs = Float32List(0);
  Float32List _playedPts = Float32List(0);
  Float32List _unplayedPts = Float32List(0);

  double _pxPerSample(double z) =>
      z * kPxPerSecondAt1x / math.max(1, project.sampleRate);

  /// Index into `project.beats` of the visible marker under a tap at [dx], or
  /// null if none is within [slopPx]. Hidden (filtered-out) beats are not
  /// tappable (§6.2). Taps above the section tint (ruler, labels) are ignored.
  static int? beatAt({
    required Project project,
    required int playheadSample,
    required double zoom,
    required double dx,
    required double dy,
    required double width,
    // Under half the 24 px beat spacing at 4x, so empty space between
    // markers stays tappable (deselects). Zoom in for finer targets.
    double slopPx = 10,
  }) {
    if (dy < _tintTop || project.beats.isEmpty) return null;
    final visible = visibleBeatIndices(project);
    if (visible.isEmpty) return null;
    final pxPerSample =
        zoom * kPxPerSecondAt1x / math.max(1, project.sampleRate);
    final sampleAtTap = playheadSample + (dx - width / 2) / pxPerSample;
    final beats = project.beats;
    final hi = _lowerBoundVisible(beats, visible, sampleAtTap);
    int? best;
    var bestPx = slopPx;
    for (final vIdx in [hi - 1, hi]) {
      if (vIdx < 0 || vIdx >= visible.length) continue;
      final realIndex = visible[vIdx];
      final px = (beats[realIndex].sample - sampleAtTap).abs() * pxPerSample;
      if (px <= bestPx) {
        best = realIndex;
        bestPx = px;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ph = playhead.value;
    final pps = _pxPerSample(zoom.value);
    final cx = size.width / 2;
    double xOf(num sample) => cx + (sample - ph) * pps;
    final visibleFrom = ph - cx / pps;
    final visibleTo = ph + cx / pps;

    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, -8, size.width, size.height));
    _paintSections(canvas, size, xOf, visibleFrom, visibleTo);
    _paintRuler(canvas, xOf, pps, visibleFrom, visibleTo);
    _paintWaveform(canvas, size, ph, pps, visibleFrom);
    _paintBeats(canvas, size, xOf, pps, visibleFrom, visibleTo);
    canvas.restore();
    _paintPlayhead(canvas, size, cx, ph);
  }

  void _paintSections(
    Canvas canvas,
    Size size,
    double Function(num) xOf,
    double from,
    double to,
  ) {
    for (final s in _effectiveSections) {
      if (s.endSample < from || s.startSample > to) continue;
      final color = Color(s.colorArgb);
      final l = xOf(s.startSample).clamp(0.0, size.width);
      final r = xOf(s.endSample).clamp(0.0, size.width);
      canvas.drawRect(
        Rect.fromLTRB(l, _tintTop, r, size.height),
        Paint()..color = color.withValues(alpha: 0.07),
      );

      if (s.startSample > 0 && s.startSample >= from) {
        _dashedVLine(
          canvas,
          xOf(s.startSample).roundToDouble() + 0.5,
          _sectionDividerTop,
          size.height,
          Paint()
            ..color = color.withValues(alpha: 0.6)
            ..strokeWidth = 1,
        );
      }

      final label = s.name.toUpperCase();
      final tp = _text.get(
        'sec:$label:${s.colorArgb}',
        label,
        KvText.ui(
          size: 11,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 11 * 0.08,
        ),
      );
      final w = tp.width + 16;
      var left = math.max(xOf(s.startSample), 0.0) + 6;
      // Stick to the left edge, but get pushed out by the next section.
      left = math.min(left, xOf(s.endSample) - w - 6);
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

  /// Ruler steps in milliseconds; the first one at least 45 px apart wins.
  static const _rulerStepsMs = [
    10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 15000, 30000, //
    60000, 120000, 300000, 600000,
  ];

  void _paintRuler(
    Canvas canvas,
    double Function(num) xOf,
    double pps,
    double fromSample,
    double toSample,
  ) {
    final rate = math.max(1, project.sampleRate);
    final pxPerMs = pps * rate / 1000;
    final step = _rulerStepsMs.firstWhere(
      (s) => s * pxPerMs >= 45,
      orElse: () => _rulerStepsMs.last,
    );
    final millis = step < 1000;
    final style = KvText.mono(size: 11, color: colors.text3);
    final fromMs = fromSample * 1000 / rate;
    final toMs = toSample * 1000 / rate;
    var ms = (fromMs / step).floor() * step;
    while (ms <= toMs + step) {
      if (ms >= 0) {
        final x = xOf(ms * rate / 1000);
        canvas.drawRect(Rect.fromLTWH(x, _rulerTickTop, 1, 8), _tick);
        final label = formatClock(ms, millis: millis);
        _text
            .get('ruler:$label', label, style)
            .paint(canvas, Offset(x + 4, _rulerLabelTop));
      }
      ms += step;
    }
  }

  void _paintWaveform(
    Canvas canvas,
    Size size,
    int ph,
    double pps,
    double fromSample,
  ) {
    if (peaks.isEmpty) return;
    final waveH = size.height - _waveTop;
    final mid = _waveTop + waveH / 2;
    final half = waveH / 2 * 0.97;
    final cx = size.width / 2;
    final framesPerBar = kWaveBarStep / pps;

    // Columns sit on a fixed frame grid so bars don't shimmer while scrolling.
    final firstCol = (fromSample / framesPerBar).floor() - 1;
    final cols = (size.width / kWaveBarStep).ceil() + 3;
    if (_mins.length < cols) {
      _mins = Float32List(cols);
      _maxs = Float32List(cols);
      _playedPts = Float32List(cols * 4);
      _unplayedPts = Float32List(cols * 4);
    }
    peaks.fillColumns(
      fromFrame: firstCol * framesPerBar,
      framesPerColumn: framesPerBar,
      columns: cols,
      outMin: _mins,
      outMax: _maxs,
      raw: pcm?.window,
    );

    var np = 0, nu = 0;
    for (var k = 0; k < cols; k++) {
      final mn = _mins[k];
      if (mn.isNaN) continue;
      final startFrame = (firstCol + k) * framesPerBar;
      final x = cx + (startFrame - ph) * pps + _barWidth / 2;
      var top = mid - _maxs[k] * half;
      var bottom = mid - mn * half;
      if (bottom - top < 2) {
        final c = (top + bottom) / 2;
        top = c - 1;
        bottom = c + 1;
      }
      if (startFrame < ph) {
        _playedPts
          ..[np++] = x
          ..[np++] = top
          ..[np++] = x
          ..[np++] = bottom;
      } else {
        _unplayedPts
          ..[nu++] = x
          ..[nu++] = top
          ..[nu++] = x
          ..[nu++] = bottom;
      }
    }
    final played = Float32List.sublistView(_playedPts, 0, np);
    final unplayed = Float32List.sublistView(_unplayedPts, 0, nu);
    canvas
      ..drawRawPoints(ui.PointMode.lines, played, _waveGlow)
      ..drawRawPoints(ui.PointMode.lines, unplayed, _waveGlow)
      ..drawRawPoints(ui.PointMode.lines, played, _played)
      ..drawRawPoints(ui.PointMode.lines, unplayed, _unplayed);
  }

  void _paintBeats(
    Canvas canvas,
    Size size,
    double Function(num) xOf,
    double pps,
    double fromSample,
    double toSample,
  ) {
    final beats = _effectiveBeats;
    if (beats.isEmpty) return;
    final visible = visibleBeatIndicesForList(beats, _effectiveFilter);
    if (visible.isEmpty) return;

    final pad = 40 / pps;
    var vi = _lowerBoundVisible(beats, visible, fromSample - pad);

    double? selectedX;
    var prevX = double.negativeInfinity;
    var lastLineX = double.negativeInfinity;
    for (
      ;
      vi < visible.length && beats[visible[vi]].sample <= toSample + pad;
      vi++
    ) {
      final i = visible[vi];
      final b = beats[i];
      final x = xOf(b.sample);
      if (i == selectedIndex) {
        selectedX = x; // drawn last so nothing covers it
        prevX = x;
        continue;
      }
      final nextX = vi + 1 < visible.length
          ? xOf(beats[visible[vi + 1]].sample)
          : double.infinity;
      final detailed = math.min(x - prevX, nextX - x) >= _detailedBeatSpacingPx;
      prevX = x;

      if (!detailed) {
        // Zoomed far out: thin lines, thinned so they never hide the
        // waveform. Drops are always shown.
        if (b.type != BeatType.drop && x - lastLineX < _minLineGapPx) continue;
        lastLineX = x;
        canvas.drawRect(
          Rect.fromLTRB(x - 0.5, _strongLineTop, x + 0.5, size.height),
          switch (b.type) {
            BeatType.beat => _farBeatLine,
            BeatType.drop => _solid,
            _ => _beatLine,
          },
        );
        continue;
      }
      switch (b.type) {
        case BeatType.beat:
          canvas
            ..drawRect(
              Rect.fromLTRB(x - 0.75, _beatLineTop, x + 0.75, size.height),
              _beatLine,
            )
            ..drawCircle(Offset(x, _dotTop + 3), 3, _beatDot);
        case BeatType.strong:
        case BeatType.downbeat:
          final isDownbeat = b.type == BeatType.downbeat;
          final line = Rect.fromLTRB(
            x - 1.25,
            _strongLineTop,
            x + 1.25,
            size.height,
          );
          final label = isDownbeat ? '1' : '${i + 1}';
          final tp = _text.get(
            'pill:$label',
            label,
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
          final fill = isDownbeat ? _downbeatSolid : _solid;
          canvas
            ..drawRect(line, _glow)
            ..drawRRect(pill, _glow)
            ..drawRect(line, fill)
            ..drawRRect(pill, fill);
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
            ..drawRect(line, _glow)
            ..drawRRect(flag, _glow)
            ..drawRect(line, _solid)
            ..drawRRect(flag, _solid);
          final tp = _text.get(
            'drop',
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
    final tp = _text.get(
      'sel:$number',
      '$number',
      KvText.mono(size: 12, weight: FontWeight.w700, color: colors.onVolt),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintPlayhead(Canvas canvas, Size size, double cx, int ph) {
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
    // Changes every frame; not worth caching.
    final tp = TextPainter(
      text: TextSpan(
        text: formatClock(project.sampleToMs(ph), millis: true),
        style: KvText.mono(
          size: 11,
          weight: FontWeight.w700,
          color: colors.onVolt,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, _bubbleTop + (22 - tp.height) / 2),
    );
  }

  static int _lowerBoundVisible(
    List<Beat> beats,
    List<int> visible,
    double sample,
  ) {
    var lo = 0;
    var hi = visible.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (beats[visible[mid]].sample < sample) {
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

  @override
  bool shouldRepaint(TimelinePainter old) =>
      old.project != project ||
      !identical(old.peaks, peaks) ||
      old.playhead != playhead ||
      old.zoom != zoom ||
      old.pcm != pcm ||
      old.selectedIndex != selectedIndex ||
      old.beatsOverride != beatsOverride ||
      old.filterOverride != filterOverride ||
      old.sectionsOverride != sectionsOverride ||
      old.colors != colors;
}

/// Whole-song strip, static part: section tints and the mini waveform.
/// Repaints only when the project or size changes.
class OverviewPainter extends CustomPainter {
  OverviewPainter({
    required this.project,
    required this.peaks,
    required this.colors,
  });

  final Project project;
  final PeakPyramid peaks;
  final KvColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final totalSamples = math.max(1, project.sampleCount).toDouble();
    double xOf(num sample) => sample / totalSamples * size.width;
    final strip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas
      ..save()
      ..clipRRect(strip)
      ..drawRRect(strip, Paint()..color = colors.surface1);

    for (final Section s in project.sections) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(s.startSample), 0, xOf(s.endSample), size.height),
        Paint()..color = Color(s.colorArgb).withValues(alpha: 0.14),
      );
    }

    if (!peaks.isEmpty) {
      const step = 2.0;
      final cols = (size.width / step).floor();
      final mins = Float32List(cols), maxs = Float32List(cols);
      peaks.fillColumns(
        fromFrame: 0,
        framesPerColumn: totalSamples / cols,
        columns: cols,
        outMin: mins,
        outMax: maxs,
      );
      final pts = Float32List(cols * 4);
      final mid = size.height / 2;
      final half = (size.height - 1) / 2;
      var n = 0;
      for (var k = 0; k < cols; k++) {
        if (maxs[k].isNaN) continue;
        final amp = math.max(1.0, math.max(maxs[k], -mins[k]) * half);
        final x = k * step + 0.5;
        pts
          ..[n++] = x
          ..[n++] = mid - amp
          ..[n++] = x
          ..[n++] = mid + amp;
      }
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(pts, 0, n),
        Paint()
          ..color = colors.waveOverview
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OverviewPainter old) =>
      old.project != project ||
      !identical(old.peaks, peaks) ||
      old.colors != colors;
}

/// Whole-song strip, moving part: the box showing what's on screen.
class OverviewViewportPainter extends CustomPainter {
  OverviewViewportPainter({
    required this.sampleCount,
    required this.sampleRate,
    required this.playhead,
    required this.zoom,
    required this.timelineWidth,
    required this.colors,
  }) : super(repaint: Listenable.merge([playhead, zoom]));

  final int sampleCount;
  final int sampleRate;
  final ValueListenable<int> playhead;
  final ValueListenable<double> zoom;
  final double timelineWidth;
  final KvColors colors;

  late final _glowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  late final _linePaint = Paint()
    ..color = colors.text1
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final total = math.max(1, sampleCount).toDouble();
    final pps = zoom.value * kPxPerSecondAt1x / math.max(1, sampleRate);
    final visibleSamples = timelineWidth / pps;
    final w = math.min(
      size.width,
      math.max(20.0, visibleSamples / total * size.width),
    );
    final left = (playhead.value / total * size.width - w / 2).clamp(
      0.0,
      size.width - w,
    );
    final box = RRect.fromLTRBR(
      left,
      -1,
      left + w,
      size.height - 1,
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(box, _glowPaint)
      ..drawRRect(box.deflate(0.75), _linePaint);
  }

  @override
  bool shouldRepaint(OverviewViewportPainter old) =>
      old.sampleCount != sampleCount ||
      old.sampleRate != sampleRate ||
      old.playhead != playhead ||
      old.zoom != zoom ||
      old.timelineWidth != timelineWidth ||
      old.colors != colors;
}
