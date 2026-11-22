import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_constants.dart';
import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../../import/import.dart';

/// Projects home. Until M2 there are no saved projects, so this is the
/// empty state with the import entry point.
@RoutePage()
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SourcePickerCubit(),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _onPickerState(
    BuildContext context,
    SourcePickerState state,
  ) async {
    final cubit = context.read<SourcePickerCubit>();
    switch (state) {
      case SourcePickerPicked(:final source):
        cubit.reset();
        final failure = await context.router.push<ImportFailure?>(
          AnalyzingRoute(source: source),
        );
        if (failure != null && context.mounted) {
          await _showError(context, failure);
        }
      case SourcePickerLibrary(:final tracks):
        cubit.reset();
        final track = await showLibraryTrackSheet(context, tracks);
        if (track != null) cubit.chooseLibraryTrack(track);
      case SourcePickerFailed(:final failure):
        cubit.reset();
        await _showError(context, failure);
      case SourcePickerIdle() || SourcePickerBusy():
        break;
    }
  }

  Future<void> _showError(BuildContext context, ImportFailure failure) async {
    final action = await showImportErrorDialog(context, failure);
    if (!context.mounted) return;
    final cubit = context.read<SourcePickerCubit>();
    switch (action) {
      case ImportErrorAction.chooseFile:
        await cubit.pickFile();
      case ImportErrorAction.extractVideo:
        await cubit.pickVideo();
      case null:
        break;
    }
  }

  Future<void> _import(BuildContext context) async {
    final cubit = context.read<SourcePickerCubit>();
    final kind = await showImportSheet(context);
    switch (kind) {
      case ImportSourceKind.file:
        await cubit.pickFile();
      case ImportSourceKind.library:
        await cubit.openLibrary();
      case ImportSourceKind.video:
        await cubit.pickVideo();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return BlocListener<SourcePickerCubit, SourcePickerState>(
      listener: _onPickerState,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const _Header(),
                const Spacer(flex: 3),
                _EmptyArt(onTap: () => _import(context)),
                const SizedBox(height: 18),
                Text(
                  'No beat packs yet',
                  textAlign: TextAlign.center,
                  style: KvText.heading(size: 28),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 310),
                  child: Text(
                    'Import the song you’re editing to. We’ll find the beats, '
                    'you fix the rest, then export a pack for CapCut or VN.',
                    textAlign: TextAlign.center,
                    style: KvText.ui(size: 16, color: kv.text2, height: 1.45),
                  ),
                ),
                const Spacer(flex: 4),
                BlocBuilder<SourcePickerCubit, SourcePickerState>(
                  builder: (context, state) => KvPrimaryButton(
                    label: 'Import a song',
                    icon: KvIcons.plus,
                    height: 64,
                    radius: 20,
                    fontSize: 18,
                    onPressed: state is SourcePickerBusy
                        ? null
                        : () => _import(context),
                  ),
                ),
                const SizedBox(height: 8),
                // How-to guide arrives in M8.
                SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      KvIcon(KvIcons.help, size: 20, color: kv.text3),
                      const SizedBox(width: 8),
                      Text(
                        'How beat packs work',
                        style: KvText.ui(
                          size: 16,
                          weight: FontWeight.w600,
                          color: kv.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: kv.volt,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: kv.volt.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: KvIcon(KvIcons.bolt, size: 18, color: kv.onVolt),
          ),
          const SizedBox(width: 8),
          Text('KickVolt', style: KvText.heading(size: 21)),
          const Spacer(),
          // Live count comes from the entitlement service in M8.
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kv.surface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kv.border),
            ),
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${AppConstants.freeExportsPerWeek}',
                    style: KvText.mono(
                      size: 13,
                      weight: FontWeight.w600,
                      color: kv.volt,
                    ),
                  ),
                  TextSpan(
                    text: ' free left',
                    style: KvText.ui(
                      size: 13,
                      weight: FontWeight.w600,
                      color: kv.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Settings screen arrives in M8.
          const KvIconButton(
            icon: KvIcons.sliders,
            tooltip: 'Settings',
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

/// Faint waveform with a beat ruler and the glowing "+" button.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return SizedBox(
      width: 220,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            height: 80,
            child: CustomPaint(
              painter: _EmptyWavePainter(
                bar: kv.waveUnplayed.withValues(alpha: 0.7),
                tick: kv.volt,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Import a song',
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kv.volt,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kv.volt.withValues(alpha: 0.5),
                      blurRadius: 40,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: KvIcon(KvIcons.plus, size: 28, color: kv.onVolt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWavePainter extends CustomPainter {
  _EmptyWavePainter({required this.bar, required this.tick});

  final Color bar;
  final Color tick;

  // Fixed pseudo-random heights so the art is stable.
  static const _heights = [
    .45, .7, .55, .85, .6, .4, .75, .9, .5, .65, .8, .45, .7, .95, .55, .6, //
    .85, .5, .75, .4, .65, .9, .55, .7, .8, .45, .6, .85, .5, .75, .65, .9,
    .55, .7, .45, .8, .6, .95, .5, .65, .75, .55, .85, .45, .7, .6, .8, .5,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const waveH = 72.0;
    final mid = waveH / 2;
    final step = size.width / _heights.length;
    final p = Paint()
      ..color = bar
      ..strokeWidth = 2;
    for (var i = 0; i < _heights.length; i++) {
      final x = i * step + step / 2;
      final h = _heights[i] * waveH / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), p);
    }
    for (var i = 0; i <= 20; i++) {
      final major = i % 4 == 0;
      canvas.drawRect(
        Rect.fromLTWH(2.5 + i * 11, waveH + 2, major ? 2 : 1, major ? 4 : 3),
        Paint()..color = tick.withValues(alpha: major ? 1 : 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyWavePainter old) =>
      old.bar != bar || old.tick != tick;
}
