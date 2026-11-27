import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../onboarding/domain/first_run.dart';

/// First-run editor coach-mark overlay (`Coach1`–`Coach3`, M8 §4.3).
///
/// Tracks the real editor target widgets (waveform, tool tabs, Export pill) via
/// [GlobalKey]s and their [RenderBox] bounds, punching out a rounded cut-out
/// from a dimmed scrim and framing it with a 2 px volt border.
class CoachMarksOverlay extends StatefulWidget {
  const CoachMarksOverlay({
    super.key,
    required this.waveformKey,
    required this.toolsKey,
    required this.exportPillKey,
    required this.onDismissed,
  });

  final GlobalKey waveformKey;
  final GlobalKey toolsKey;
  final GlobalKey exportPillKey;
  final VoidCallback onDismissed;

  @override
  State<CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<CoachMarksOverlay> {
  final GlobalKey _overlayKey = GlobalKey();
  CoachMarkStep _step = CoachMarkStep.waveform;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  GlobalKey _keyFor(CoachMarkStep step) => switch (step) {
    CoachMarkStep.waveform => widget.waveformKey,
    CoachMarkStep.tools => widget.toolsKey,
    CoachMarkStep.exportPill => widget.exportPillKey,
  };

  Rect? _measureNow() {
    final overlayObj = _overlayKey.currentContext?.findRenderObject();
    final targetObj = _keyFor(_step).currentContext?.findRenderObject();
    if (overlayObj is! RenderBox ||
        targetObj is! RenderBox ||
        !overlayObj.hasSize ||
        !targetObj.hasSize) {
      return null;
    }
    final topLeft = targetObj.localToGlobal(Offset.zero, ancestor: overlayObj);
    return topLeft & targetObj.size;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final measured = _measureNow();
      if (measured != null && measured != _targetRect) {
        setState(() => _targetRect = measured);
      }
    });
  }

  void _advance() {
    final next = _step.next;
    if (next == null) {
      widget.onDismissed();
      return;
    }
    setState(() {
      _step = next;
      _targetRect = null;
    });
    final immediate = _measureNow();
    if (immediate != null) {
      setState(() => _targetRect = immediate);
    } else {
      _scheduleMeasure();
    }
  }

  RRect _cutoutFor(Size overlaySize, Rect? raw) {
    switch (_step) {
      case CoachMarkStep.waveform:
        final base = raw ?? Rect.fromLTWH(6, 140, overlaySize.width - 12, 290);
        final left = math.max(6.0, base.left);
        final right = math.min(overlaySize.width - 6.0, base.right);
        return RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left,
            base.top - 4,
            math.max(left + 20, right),
            base.bottom + 4,
          ),
          const Radius.circular(16),
        );
      case CoachMarkStep.tools:
        final base =
            raw ??
            Rect.fromLTWH(
              4,
              overlaySize.height - 82,
              overlaySize.width - 8,
              62,
            );
        final left = math.max(4.0, base.left);
        final right = math.min(overlaySize.width - 4.0, base.right);
        return RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left,
            base.top + 2,
            math.max(left + 20, right),
            base.bottom - 2,
          ),
          const Radius.circular(18),
        );
      case CoachMarkStep.exportPill:
        final base = raw ?? Rect.fromLTWH(overlaySize.width - 96, 56, 86, 44);
        return RRect.fromRectAndRadius(
          base.inflate(4),
          const Radius.circular(23),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return LayoutBuilder(
      key: _overlayKey,
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final measured = _measureNow() ?? _targetRect;
        if (measured == null) {
          _scheduleMeasure();
        }
        final cutout = _cutoutFor(size, measured);
        final cardAbove = _step == CoachMarkStep.tools;
        final cardWidth = _step == CoachMarkStep.exportPill
            ? math.min(304.0, size.width - 32.0)
            : size.width - 32.0;
        final cardLeft = _step == CoachMarkStep.exportPill
            ? math.max(16.0, size.width - 16.0 - cardWidth)
            : 16.0;
        final caretX = cutout.outerRect.center.dx.clamp(
          cardLeft + 24.0,
          cardLeft + cardWidth - 24.0,
        );

        return Semantics(
          container: true,
          label: 'Tip ${_step.stepLabel}',
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: _CoachCutoutPainter(
                      cutout: cutout,
                      borderColor: kv.volt,
                    ),
                  ),
                ),
              ),
              if (cardAbove)
                Positioned(
                  left: cardLeft,
                  width: cardWidth,
                  bottom: math.max(16.0, size.height - cutout.top + 14.0),
                  child: _CoachCard(
                    step: _step,
                    caretOffsetFromLeft: caretX - cardLeft,
                    caretOnTop: false,
                    onSkip: widget.onDismissed,
                    onPrimary: _advance,
                  ),
                )
              else
                Positioned(
                  left: cardLeft,
                  width: cardWidth,
                  top: math.min(
                    math.max(16.0, size.height - 230.0),
                    cutout.bottom + 14.0,
                  ),
                  child: _CoachCard(
                    step: _step,
                    caretOffsetFromLeft: caretX - cardLeft,
                    caretOnTop: true,
                    onSkip: widget.onDismissed,
                    onPrimary: _advance,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CoachCutoutPainter extends CustomPainter {
  const _CoachCutoutPainter({required this.cutout, required this.borderColor});

  final RRect cutout;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(cutout);
    final scrim = Path.combine(PathOperation.difference, full, hole);

    canvas.drawPath(scrim, Paint()..color = const Color(0xCC050508));
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CoachCutoutPainter old) =>
      old.cutout != cutout || old.borderColor != borderColor;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.caretOffsetFromLeft,
    required this.caretOnTop,
    required this.onSkip,
    required this.onPrimary,
  });

  final CoachMarkStep step;
  final double caretOffsetFromLeft;
  final bool caretOnTop;
  final VoidCallback onSkip;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    const cardBg = Color(0xFFF4F4F8);
    const bodyText = Color(0xFF3A3A4A);
    const stepText = Color(0xFF5A5A70);
    const skipText = Color(0xFF4A4A5C);

    final caret = Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(caretOffsetFromLeft - 8, caretOnTop ? 8 : -8),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 16, height: 16, color: cardBg),
        ),
      ),
    );

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            step.stepLabel,
            style: KvText.mono(
              size: 12,
              weight: FontWeight.w700,
              color: stepText,
            ),
          ),
          const SizedBox(height: 8),
          Text(step.title, style: KvText.heading(size: 20, color: kv.onVolt)),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: KvText.ui(size: 14, color: bodyText, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSkip,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Skip tips',
                          style: KvText.ui(
                            size: 14,
                            weight: FontWeight.w600,
                            color: skipText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: kv.onVolt,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPrimary,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    child: Text(
                      step.primaryButtonLabel,
                      style: KvText.ui(
                        size: 15,
                        weight: FontWeight.w700,
                        color: kv.volt,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: caretOnTop ? [caret, card] : [card, caret],
    );
  }
}
