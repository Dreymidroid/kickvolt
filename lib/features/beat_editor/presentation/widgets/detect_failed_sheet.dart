import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';

/// Bottom sheet shown when no steady beat could be found
/// (`EditorDetectFailed.png` / `EditorDetectFailed.html`).
class DetectFailedSheet extends StatelessWidget {
  const DetectFailedSheet({super.key, this.state});

  final BeatEditorReady? state;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<BeatEditorCubit>();
    final showTryTempoChanges = state?.canTryTempoChangesOnFailure ?? false;

    return Container(
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: kv.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: kv.surface3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A4C).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const KvIcon(
                      KvIcons.alertCircle,
                      size: 22,
                      color: Color(0xFFFF8A4C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No steady beat found',
                      style: KvText.heading(size: 22),
                    ),
                  ),
                  KvIconButton(
                    icon: KvIcons.close,
                    tooltip: 'Close',
                    color: kv.text2,
                    onPressed: cubit.closeSheet,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'The tempo drifts a lot in this song, or it’s mostly vocals. Try one of these:',
                style: KvText.ui(size: 14, color: kv.text2),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: KvIcons.tap,
                title: 'Tap them in',
                badge: 'BEST',
                subtitle: 'Play it and tap along. Fix them after.',
                highlighted: true,
                onTap: cubit.tapBeatsFromFailedSheet,
              ),
              if (showTryTempoChanges) ...[
                const SizedBox(height: 10),
                _ActionCard(
                  icon: KvIcons.sliders,
                  title: 'Try Tempo changes',
                  subtitle: 'Follows a drifting or shifting tempo',
                  onTap: cubit.tryTempoChangesFromFailedSheet,
                ),
              ],
              const SizedBox(height: 10),
              _ActionCard(
                icon: KvIcons.sparkle,
                title: 'Detect with more sensitivity',
                subtitle: 'Catches softer beats too',
                onTap: cubit.detectWithMoreSensitivity,
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: KvIcons.bolt,
                title: 'Mark drops only',
                subtitle: 'Just the big hits',
                onTap: cubit.markDropsOnly,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.highlighted = false,
  });

  final KvIcons icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Material(
      color: kv.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted ? kv.volt.withValues(alpha: 0.45) : kv.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kv.volt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: KvIcon(icon, size: 20, color: kv.volt),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: KvText.ui(
                              size: 15,
                              weight: FontWeight.w600,
                              color: kv.text1,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kv.volt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: KvText.ui(
                                size: 11,
                                weight: FontWeight.w700,
                                color: kv.onVolt,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: KvText.ui(size: 12, color: kv.text2)),
                  ],
                ),
              ),
              KvIcon(KvIcons.chevronRight, size: 18, color: kv.text3),
            ],
          ),
        ),
      ),
    );
  }
}
