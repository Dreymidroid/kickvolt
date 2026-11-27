import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../domain/how_to_tab.dart';
import '../widgets/how_to_step_art.dart';

/// Four-step guide for using an exported beat pack in CapCut or VN
/// (`HowToCapCut`, `HowToVN`, M8 §4.4).
@RoutePage()
class HowToScreen extends StatefulWidget {
  const HowToScreen({super.key, this.initialTab = HowToTab.capCut});

  final HowToTab initialTab;

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  late HowToTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final boldStyle = KvText.ui(
      size: 13,
      weight: FontWeight.w700,
      color: kv.text1,
      height: 1.4,
    );
    final bodyStyle = KvText.ui(size: 13, color: kv.text2, height: 1.4);

    final steps = switch (_tab) {
      HowToTab.capCut => <_StepContent>[
        _StepContent(
          number: '01',
          title: 'Import both files',
          body: TextSpan(
            style: bodyStyle,
            text:
                'Add the song and the guide track from Files to your project.',
          ),
        ),
        _StepContent(
          number: '02',
          title: 'Line them up at 0:00',
          body: TextSpan(
            style: bodyStyle,
            text:
                'Both tracks start at the very beginning, one under the other.',
          ),
        ),
        _StepContent(
          number: '03',
          title: 'Run auto-beats on the guide',
          body: TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(text: 'Tap the guide track, open '),
              TextSpan(text: 'Beats', style: boldStyle),
              const TextSpan(text: ', turn on '),
              TextSpan(text: 'Auto generate', style: boldStyle),
              const TextSpan(text: '. Every click becomes a beat dot.'),
            ],
          ),
        ),
        _StepContent(
          number: '04',
          title: 'Mute the guide',
          body: TextSpan(
            style: bodyStyle,
            text: 'Set its volume to 0. The beat dots stay, the clicks don’t.',
          ),
        ),
      ],
      HowToTab.vn => <_StepContent>[
        _StepContent(
          number: '01',
          title: 'Import both files',
          body: TextSpan(
            style: bodyStyle,
            text:
                'Add the song and the guide track as music: '
                'Music › Yours › ⋮ › File App.',
          ),
        ),
        _StepContent(
          number: '02',
          title: 'Line them up at 0:00',
          body: TextSpan(
            style: bodyStyle,
            text:
                'Both tracks start at the very beginning, one under the other.',
          ),
        ),
        _StepContent(
          number: '03',
          title: 'Run auto-beats on the guide',
          body: TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(text: 'Tap the guide track, open '),
              TextSpan(text: 'Beats', style: boldStyle),
              const TextSpan(text: ' and tap '),
              TextSpan(text: 'Auto Beats', style: boldStyle),
              const TextSpan(
                text: '. Then tap ✓. Every click becomes a beat point.',
              ),
            ],
          ),
        ),
        _StepContent(
          number: '04',
          title: 'Mute the guide',
          body: TextSpan(
            style: bodyStyle,
            text: 'Set its volume to 0. The beat dots stay, the clicks don’t.',
          ),
        ),
      ],
    };

    return Scaffold(
      backgroundColor: kv.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  KvIconButton(
                    icon: KvIcons.chevronLeft,
                    tooltip: 'Back',
                    onPressed: () => context.router.maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Use your beat pack',
                      style: KvText.heading(size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KvSegmented<HowToTab>(
                semanticLabel: 'Editor app',
                value: _tab,
                options: const [
                  (HowToTab.capCut, 'CapCut'),
                  (HowToTab.vn, 'VN'),
                ],
                onChanged: (next) => setState(() => _tab = next),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final (index, step) in steps.indexed) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _HowToStepCard(stepIndex: index + 1, content: step),
                  ],
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: KvIcon(
                            KvIcons.help,
                            size: 18,
                            color: kv.text3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Beats a little early or late? In KickVolt, use '
                            'Bulk › Shift all beats, then export again.',
                            style: KvText.ui(
                              size: 13,
                              color: kv.text2,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepContent {
  const _StepContent({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final TextSpan body;
}

class _HowToStepCard extends StatelessWidget {
  const _HowToStepCard({required this.stepIndex, required this.content});

  final int stepIndex;
  final _StepContent content;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kv.border),
      ),
      child: Row(
        children: [
          HowToStepArt(stepNumber: stepIndex),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      content.number,
                      style: KvText.mono(
                        size: 12,
                        weight: FontWeight.w700,
                        color: kv.volt,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        content.title,
                        style: KvText.ui(
                          size: 15,
                          weight: FontWeight.w600,
                          color: kv.text1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(content.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
