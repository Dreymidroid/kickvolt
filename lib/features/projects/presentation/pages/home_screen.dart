import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../../import/import.dart';
import '../../bloc/projects_cubit.dart';
import '../../domain/entities/project_summary.dart';
import '../widgets/project_card.dart';
import '../widgets/project_dialogs.dart';

/// Projects home: shows saved beat packs (newest first) or the empty state
/// when no projects exist yet.
@RoutePage()
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.projectsCubit, this.pickerCubit});

  final ProjectsCubit? projectsCubit;
  final SourcePickerCubit? pickerCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => pickerCubit ?? SourcePickerCubit()),
        BlocProvider(create: (_) => projectsCubit ?? (ProjectsCubit()..load())),
      ],
      child: const HomeView(),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  StackRouter? _router;
  bool _wasTopRoute = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = AutoRouter.of(context);
    if (_router != router) {
      _router?.navigationHistory.removeListener(_onNavigationChanged);
      _router = router;
      _wasTopRoute = router.current.name == HomeRoute.name;
      router.navigationHistory.addListener(_onNavigationChanged);
    }
  }

  @override
  void dispose() {
    _router?.navigationHistory.removeListener(_onNavigationChanged);
    super.dispose();
  }

  void _onNavigationChanged() {
    if (!mounted) return;
    final isTop = _router?.current.name == HomeRoute.name;
    if (isTop && !_wasTopRoute) {
      context.read<ProjectsCubit>().load();
    }
    _wasTopRoute = isTop;
  }

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
        if (!context.mounted) return;
        await context.read<ProjectsCubit>().load();
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

  Future<void> _openProject(
    BuildContext context,
    ProjectSummary summary,
  ) async {
    await context.router.push(BeatEditorRoute(projectId: summary.id));
    if (context.mounted) {
      await context.read<ProjectsCubit>().load();
    }
  }

  Future<void> _onCardLongPress(
    BuildContext context,
    ProjectSummary summary,
  ) async {
    final action = await showProjectActionsSheet(context, summary);
    if (!context.mounted || action == null) return;
    final projectsCubit = context.read<ProjectsCubit>();
    switch (action) {
      case ProjectCardAction.rename:
        final newTitle = await showRenameProjectDialog(
          context,
          currentTitle: summary.title,
        );
        if (newTitle != null && context.mounted) {
          await projectsCubit.rename(summary.id, newTitle);
        }
      case ProjectCardAction.delete:
        final confirmed = await showDeleteProjectDialog(
          context,
          title: summary.title,
        );
        if (confirmed && context.mounted) {
          await projectsCubit.delete(summary.id);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return BlocListener<SourcePickerCubit, SourcePickerState>(
      listener: _onPickerState,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<ProjectsCubit, ProjectsState>(
            builder: (context, state) => switch (state) {
              ProjectsLoading() => Column(
                children: [
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _Header(),
                  ),
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: kv.volt),
                    ),
                  ),
                ],
              ),
              ProjectsError(:final error) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _Header(),
                    const Spacer(),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: KvText.ui(size: 15, color: kv.error),
                    ),
                    const SizedBox(height: 16),
                    KvSecondaryButton(
                      label: 'Try again',
                      onPressed: () => context.read<ProjectsCubit>().load(),
                    ),
                    const Spacer(),
                    _ImportButton(onImport: () => _import(context)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              ProjectsLoaded(:final projects) =>
                projects.isEmpty
                    ? _EmptyHomeBody(onImport: () => _import(context))
                    : _ProjectsListBody(
                        projects: projects,
                        onImport: () => _import(context),
                        onOpenProject: (s) => _openProject(context, s),
                        onLongPressProject: (s) => _onCardLongPress(context, s),
                      ),
            },
          ),
        ),
      ),
    );
  }
}

class _ProjectsListBody extends StatelessWidget {
  const _ProjectsListBody({
    required this.projects,
    required this.onImport,
    required this.onOpenProject,
    required this.onLongPressProject,
  });

  final List<ProjectSummary> projects;
  final VoidCallback onImport;
  final ValueChanged<ProjectSummary> onOpenProject;
  final ValueChanged<ProjectSummary> onLongPressProject;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final now = DateTime.now();
    final countLabel =
        '${projects.length} ${projects.length == 1 ? 'song' : 'songs'}';

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const _Header(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Projects', style: KvText.heading(size: 34)),
                  Text(countLabel, style: KvText.ui(size: 14, color: kv.text2)),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 112),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final summary = projects[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ProjectCard(
                        summary: summary,
                        now: now,
                        onTap: () => onOpenProject(summary),
                        onLongPress: () => onLongPressProject(summary),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kv.background.withValues(alpha: 0),
                  kv.background.withValues(alpha: 0.92),
                  kv.background,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
            child: _ImportButton(onImport: onImport, height: 60),
          ),
        ),
      ],
    );
  }
}

class _EmptyHomeBody extends StatelessWidget {
  const _EmptyHomeBody({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const _Header(),
          const Spacer(flex: 3),
          _EmptyArt(onTap: onImport),
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
          _ImportButton(onImport: onImport),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.router.push(HowToRoute()),
            child: SizedBox(
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.onImport, this.height = 64});

  final VoidCallback onImport;
  final double height;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SourcePickerCubit, SourcePickerState>(
      builder: (context, state) => KvPrimaryButton(
        label: 'Import a song',
        icon: KvIcons.plus,
        height: height,
        radius: 20,
        fontSize: 18,
        onPressed: state is SourcePickerBusy ? null : onImport,
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
          KvIconButton(
            icon: KvIcons.sliders,
            tooltip: 'Settings',
            onPressed: () => context.router.push(SettingsRoute()),
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
