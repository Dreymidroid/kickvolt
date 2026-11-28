import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/audio_math/click_synth.dart';
import '../../../../core/entitlements/entitlement_service.dart';
import '../../../../shared/shared.dart';
import '../../../import/presentation/widgets/library_track_sheet.dart'
    show formatDuration;
import '../../../projects/domain/entities/project.dart';
import '../../bloc/export_cubit.dart';
import '../../domain/entities/beat_pack.dart';
import '../../domain/entities/export_options.dart';

/// Warning shown under the format chips when M4A is selected (§4.6).
const String kM4aWarning =
    'M4A is smaller, but some editors shift it by a few milliseconds. Use '
    'WAV for exact sync.';

String _flashes(int n) => '$n ${n == 1 ? 'flash' : 'flashes'}';

String _clickStyleLabel(ClickStyle s) => switch (s) {
  ClickStyle.snap => 'Snap',
  ClickStyle.rim => 'Rim',
  ClickStyle.blip => 'Blip',
  ClickStyle.kick => 'Kick',
};

/// The Export options screen (`Export.png`).
class ExportOptionsView extends StatelessWidget {
  const ExportOptionsView({
    super.key,
    required this.project,
    required this.options,
    required this.plan,
    required this.quota,
    this.videoAllowed = true,
    this.onVideoLocked,
  });

  final Project project;
  final ExportOptions options;
  final BeatPackPlan plan;
  final ExportQuota quota;

  /// `Entitlements.hasGuideVideo` (M7 §6).
  final bool videoAllowed;

  /// Called when the locked Guide video row is tapped (does nothing today).
  final VoidCallback? onVideoLocked;

  static String _bpm(double? bpm) => bpm == null
      ? '– BPM'
      : '${bpm == bpm.roundToDouble() ? bpm.round() : bpm.toStringAsFixed(1)} BPM';

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<ExportCubit>();
    final beats = plan.clickCount;
    final canExport = beats > 0;
    final label = canExport
        ? 'Export ${plan.fileCount} ${plan.fileCount == 1 ? 'file' : 'files'}'
        : 'Mark some beats first';

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    KvIconButton(
                      icon: KvIcons.chevronLeft,
                      tooltip: 'Back',
                      onPressed: () => context.router.maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Export beat pack',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KvText.heading(size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Card(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KvText.ui(
                          size: 16,
                          weight: FontWeight.w600,
                          color: kv.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$beats ${beats == 1 ? 'beat' : 'beats'} · '
                        '${_bpm(project.bpm)} · '
                        '${formatDuration(project.durationMs)}',
                        style: KvText.mono(size: 12, color: kv.text2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionLabel('In the pack'),
                const SizedBox(height: 8),
                _Card(
                  radius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      _PackRow(
                        icon: KvIcons.music,
                        title: 'Song',
                        subtitle: 'Clean, untouched',
                        trailing: _Switch(
                          value: options.includeSong,
                          label: 'Include song',
                        ),
                      ),
                      _PackRow(
                        icon: KvIcons.bolt,
                        title: 'Guide track',
                        subtitle: 'Silent, with a click on every beat',
                        trailing: _Switch(
                          value: options.includeGuide,
                          label: 'Include guide track',
                        ),
                      ),
                      // M7 §6: a toggle with `hasGuideVideo`; otherwise a
                      // disabled row whose tap calls [onVideoLocked]. No PRO
                      // badge, no paywall.
                      GestureDetector(
                        key: const ValueKey('export-video-row'),
                        behavior: HitTestBehavior.opaque,
                        onTap: videoAllowed ? null : onVideoLocked,
                        child: Opacity(
                          opacity: videoAllowed ? 1 : 0.45,
                          child: _PackRow(
                            icon: KvIcons.video,
                            title: 'Guide video',
                            subtitle:
                                'Black clip that flashes each beat number',
                            trailing: _Switch(
                              value: videoAllowed && options.includeVideo,
                              label: 'Include guide video',
                              onChanged: videoAllowed
                                  ? cubit.setIncludeVideo
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      _PackRow(
                        icon: KvIcons.volume,
                        title: 'Preview mix',
                        subtitle: 'Song with the clicks you can hear',
                        trailing: _Switch(
                          value: options.includePreview,
                          label: 'Include preview mix',
                          onChanged: cubit.setIncludePreview,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionLabel('Click sound'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (i, style) in ClickStyle.values.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _ClickChip(
                          label: _clickStyleLabel(style),
                          selected: options.clickStyle == style,
                          onTap: () => cubit.setClickStyle(style),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Audio format',
                        style: KvText.ui(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: KvSegmented<AudioFormat>(
                        semanticLabel: 'Audio format',
                        mono: true,
                        fontSize: 13,
                        value: options.format,
                        options: const [
                          (AudioFormat.m4a, 'M4A'),
                          (AudioFormat.wav, 'WAV'),
                        ],
                        onChanged: cubit.setFormat,
                      ),
                    ),
                  ],
                ),
                if (options.format == AudioFormat.m4a) ...[
                  const SizedBox(height: 8),
                  Text(
                    kM4aWarning,
                    style: KvText.ui(size: 12, color: kv.warning, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                _Card(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      for (final f in plan.files)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: KvText.mono(size: 12, color: kv.text1),
                                ),
                              ),
                              Text(
                                f.kind == ExportFileKind.video
                                    ? '${formatDuration(plan.durationMs)} · '
                                          '${_flashes(plan.guideVideo?.flashCount ?? 0)}'
                                    : f.clickCount == null
                                    ? formatDuration(plan.durationMs)
                                    : '${formatDuration(plan.durationMs)} · '
                                          '${f.clickCount} '
                                          '${f.clickCount == 1 ? 'click' : 'clicks'}',
                                style: KvText.mono(size: 12, color: kv.text2),
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
        ),
        Container(
          decoration: BoxDecoration(
            color: kv.background,
            border: Border(top: BorderSide(color: kv.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                KvPrimaryButton(
                  label: label,
                  icon: canExport ? KvIcons.download : null,
                  onPressed: canExport ? cubit.startExport : null,
                ),
                if (!quota.isUnlimited)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Uses 1 of your ${quota.limit} free exports this week',
                      style: KvText.ui(size: 12, color: kv.text2),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    required this.radius,
    required this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kv.border),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: KvText.ui(
      size: 12,
      weight: FontWeight.w600,
      letterSpacing: 0.96,
      color: context.kv.text3,
    ),
  );
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final KvIcons icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kv.surface2,
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
                Text(
                  title,
                  style: KvText.ui(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: KvText.ui(size: 12, color: kv.text2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.label, this.onChanged});

  final bool value;
  final String label;

  /// Null = always on / not changeable.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          width: 52,
          height: 32,
          decoration: BoxDecoration(
            color: value ? kv.volt : kv.surface3,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 120),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(3),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? kv.onVolt : kv.text2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClickChip extends StatelessWidget {
  const _ClickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final fg = selected ? kv.volt : kv.text1;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: selected ? kv.volt.withValues(alpha: 0.12) : kv.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kv.volt.withValues(alpha: 0.6) : kv.border,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KvIcon(KvIcons.play, size: 12, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: KvText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
