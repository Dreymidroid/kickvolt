import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_constants.dart';
import '../../../../app/app_router.dart';
import '../../../../core/audio_math/click_synth.dart';
import '../../../../shared/shared.dart';
import '../../../export/domain/entities/export_options.dart';
import '../../bloc/settings_cubit.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/sensitivity_preset.dart';

String _clickStyleLabel(ClickStyle style) => switch (style) {
  ClickStyle.snap => 'Snap',
  ClickStyle.rim => 'Rim',
  ClickStyle.blip => 'Blip',
  ClickStyle.kick => 'Kick',
};

String _audioFormatLabel(AudioFormat format) => switch (format) {
  AudioFormat.wav => 'WAV',
  AudioFormat.m4a => 'M4A',
};

/// App Settings screen (`Settings.png` minus Pro banner, Theme row, and M7
/// video rows, M8 §5).
@RoutePage()
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.cubit});

  final SettingsCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? (SettingsCubit()..load()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
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
                    child: Text('Settings', style: KvText.heading(size: 20)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) => switch (state) {
                  SettingsLoading() => Center(
                    child: CircularProgressIndicator(color: kv.volt),
                  ),
                  SettingsError(:final error) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: KvText.ui(size: 15, color: kv.error),
                          ),
                          const SizedBox(height: 16),
                          KvSecondaryButton(
                            label: 'Try again',
                            onPressed: () =>
                                context.read<SettingsCubit>().load(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SettingsReady(:final settings) => _SettingsBody(
                    settings: settings,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.settings});

  final AppSettings settings;

  Future<void> _pickClickStyle(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final picked = await _showOptionSheet<ClickStyle>(
      context: context,
      title: 'Click sound',
      current: settings.defaultClickStyle,
      options: [
        for (final s in ClickStyle.values)
          _SheetOption(value: s, label: _clickStyleLabel(s)),
      ],
    );
    if (picked != null) {
      await cubit.setDefaultClickStyle(picked);
    }
  }

  Future<void> _pickAudioFormat(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final picked = await _showOptionSheet<AudioFormat>(
      context: context,
      title: 'Audio format',
      current: settings.defaultAudioFormat,
      options: const [
        _SheetOption(
          value: AudioFormat.wav,
          label: 'WAV',
          subtitle: 'Uncompressed, exact sample sync',
        ),
        _SheetOption(
          value: AudioFormat.m4a,
          label: 'M4A',
          subtitle: 'Smaller files; some editors may shift by a few ms',
        ),
      ],
    );
    if (picked != null) {
      await cubit.setDefaultAudioFormat(picked);
    }
  }

  Future<void> _pickSensitivity(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final picked = await _showOptionSheet<SensitivityPreset>(
      context: context,
      title: 'Detection sensitivity',
      current: settings.sensitivityPreset,
      options: const [
        _SheetOption(
          value: SensitivityPreset.low,
          label: 'Low',
          subtitle: 'Fewer strong beats on busy songs',
        ),
        _SheetOption(
          value: SensitivityPreset.balanced,
          label: 'Balanced',
          subtitle: 'Recommended for most songs',
        ),
        _SheetOption(
          value: SensitivityPreset.high,
          label: 'High',
          subtitle: 'Catches quieter hits on soft songs',
        ),
      ],
    );
    if (picked != null) {
      await cubit.setSensitivityPreset(picked);
    }
  }

  Future<void> _openAboutDialog(BuildContext context) async {
    final kv = context.kv;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kv.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kv.border),
        ),
        title: Text(
          'KickVolt v${AppConstants.appVersion}',
          style: KvText.heading(size: 20, color: kv.text1),
        ),
        content: Text(
          'Beat-pack editor for CapCut and VN.',
          style: KvText.ui(size: 14, color: kv.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: KvText.ui(
                size: 14,
                weight: FontWeight.w600,
                color: kv.volt,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final versionLabel = 'KickVolt v${AppConstants.appVersion}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const _SettingsSectionHeader('Export defaults'),
        const SizedBox(height: 8),
        _SettingsCard(
          children: [
            _SettingsPickerRow(
              label: 'Click sound',
              value: _clickStyleLabel(settings.defaultClickStyle),
              onTap: () => _pickClickStyle(context),
            ),
            const _SettingsDivider(),
            _SettingsPickerRow(
              label: 'Audio format',
              value: _audioFormatLabel(settings.defaultAudioFormat),
              onTap: () => _pickAudioFormat(context),
            ),
            const _SettingsDivider(),
            _SettingsToggleRow(
              label: 'Mono guide track (smaller file)',
              value: settings.monoGuideTrack,
              onChanged: cubit.setMonoGuideTrack,
            ),
            const _SettingsDivider(),
            _SettingsToggleRow(
              label: 'Preview mix in packs',
              value: settings.includePreviewByDefault,
              onChanged: cubit.setIncludePreviewByDefault,
            ),
            const _SettingsDivider(),
            _SettingsPickerRow(
              label: 'Detection sensitivity',
              value: settings.sensitivityPreset.label,
              onTap: () => _pickSensitivity(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SettingsSectionHeader('Feel'),
        const SizedBox(height: 8),
        _SettingsCard(
          children: [
            _SettingsToggleRow(
              label: 'Haptics',
              value: settings.hapticsEnabled,
              onChanged: cubit.setHapticsEnabled,
            ),
            const _SettingsDivider(),
            _SettingsPickerRow(
              label: 'Tap timing (lag fix)',
              value: '${settings.latencyOffsetMs} ms',
              monoValue: true,
              onTap: () async {
                await context.router.push(LatencyCalibrationRoute());
                if (context.mounted) {
                  await cubit.refresh();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SettingsSectionHeader('Help'),
        const SizedBox(height: 8),
        _SettingsCard(
          children: [
            _SettingsPickerRow(
              label: 'How to use a beat pack',
              onTap: () => context.router.push(HowToRoute()),
            ),
            const _SettingsDivider(),
            _SettingsPickerRow(
              label: 'Send feedback',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await cubit.sendFeedback();
                if (!ok) {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open mail app (${AppConstants.feedbackEmail})',
                        ),
                      ),
                    );
                }
              },
            ),
            const _SettingsDivider(),
            _SettingsPickerRow(
              label: 'Privacy',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await cubit.openPrivacyPolicy();
                if (!ok) {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Could not open privacy policy'),
                      ),
                    );
                }
              },
            ),
            const _SettingsDivider(),
            _SettingsPickerRow(
              label: 'About',
              value: versionLabel,
              showChevron: false,
              onTap: () => _openAboutDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: KvText.ui(
        size: 12,
        weight: FontWeight.w600,
        letterSpacing: 0.96,
        color: context.kv.text3,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kv.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(height: 1, color: context.kv.border),
    );
  }
}

class _SettingsPickerRow extends StatelessWidget {
  const _SettingsPickerRow({
    required this.label,
    this.value,
    this.monoValue = false,
    this.showChevron = true,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool monoValue;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: KvText.ui(
                      size: 15,
                      weight: FontWeight.w500,
                      color: kv.text1,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: monoValue
                        ? KvText.mono(size: 14, color: kv.text2)
                        : KvText.ui(size: 14, color: kv.text2),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 4),
                  KvIcon(KvIcons.chevronRight, size: 16, color: kv.text3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: KvText.ui(
                  size: 15,
                  weight: FontWeight.w500,
                  color: kv.text1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              label: label,
              toggled: value,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(!value),
                child: Container(
                  width: 52,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? kv.volt : kv.surface3,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 120),
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption<T> {
  const _SheetOption({required this.value, required this.label, this.subtitle});

  final T value;
  final String label;
  final String? subtitle;
}

Future<T?> _showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required T current,
  required List<_SheetOption<T>> options,
}) {
  final kv = context.kv;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: kv.surface1,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: kv.border),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 14),
            Text(title, style: KvText.heading(size: 20, color: kv.text1)),
            const SizedBox(height: 10),
            for (final opt in options)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(sheetContext).pop(opt.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt.label,
                                style: KvText.ui(
                                  size: 16,
                                  weight: opt.value == current
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: opt.value == current
                                      ? kv.volt
                                      : kv.text1,
                                ),
                              ),
                              if (opt.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  opt.subtitle!,
                                  style: KvText.ui(size: 12, color: kv.text2),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (opt.value == current)
                          KvIcon(KvIcons.check, size: 20, color: kv.volt),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
