import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';
import '../widgets/beat_inspector_panel.dart';
import '../widgets/beat_timeline.dart';
import '../widgets/edit_panel.dart';
import '../widgets/editor_controls.dart';
import '../widgets/editor_top_bar.dart';

@RoutePage()
class BeatEditorScreen extends StatelessWidget {
  const BeatEditorScreen({
    super.key,
    @PathParam('id') required this.projectId,
    this.cubit,
  });

  final String projectId;
  final BeatEditorCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? (BeatEditorCubit()..load(projectId)),
      child: const _BeatEditorView(),
    );
  }
}

class _BeatEditorView extends StatelessWidget {
  const _BeatEditorView();

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Scaffold(
      backgroundColor: kv.background,
      body: BlocConsumer<BeatEditorCubit, BeatEditorState>(
        listenWhen: (prev, curr) =>
            curr is BeatEditorReady &&
            curr.saveError != null &&
            (prev is! BeatEditorReady || prev.saveError != curr.saveError),
        listener: (context, state) {
          if (state is BeatEditorReady && state.saveError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('Could not save: ${state.saveError}')),
              );
          }
        },
        builder: (context, state) => switch (state) {
          BeatEditorLoading() => Center(
            child: CircularProgressIndicator(color: kv.volt),
          ),
          BeatEditorError(:final error) => _EditorErrorView(error: error),
          final BeatEditorReady s => _EditorLayout(state: s),
        },
      ),
    );
  }
}

class _EditorErrorView extends StatelessWidget {
  const _EditorErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not open project',
                textAlign: TextAlign.center,
                style: KvText.heading(size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: KvText.ui(size: 15, color: kv.error),
              ),
              const SizedBox(height: 24),
              KvSecondaryButton(
                label: 'Back to projects',
                icon: KvIcons.chevronLeft,
                onPressed: () => context.router.maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorLayout extends StatelessWidget {
  const _EditorLayout({required this.state});

  final BeatEditorReady state;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        SafeArea(bottom: false, child: EditorTopBar(state: state)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OverviewStrip(state: state, screenWidth: width),
        ),
        const SizedBox(height: 8),
        // Ruler, section labels and waveform. 288 px tall on a 390×844 phone.
        Expanded(child: BeatTimeline(state: state)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              EditorChipsRow(state: state),
              const SizedBox(height: 10),
              TransportBar(state: state),
              const SizedBox(height: 14),
              SizedBox(height: 188, child: _contextPanel()),
            ],
          ),
        ),
        ToolTabBar(tool: state.tool),
      ],
    );
  }

  Widget _contextPanel() => switch (state.tool) {
    EditorTool.edit =>
      state.selectedIndex == null
          ? EditPanel(state: state)
          : BeatInspectorPanel(state: state),
    // Built in later screens: Auto sheet, Tap pad, Sections, Bulk.
    _ => const SizedBox.shrink(),
  };
}
