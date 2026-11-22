import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';
import '../widgets/beat_inspector_panel.dart';
import '../widgets/beat_timeline.dart';
import '../widgets/edit_panel.dart';
import '../widgets/editor_controls.dart';
import '../widgets/editor_top_bar.dart';

@RoutePage()
class BeatEditorScreen extends StatelessWidget {
  const BeatEditorScreen({super.key, @PathParam('id') this.projectId = 'demo'});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Opens at 0:15 like the design until projects remember their playhead.
      create: (_) =>
          BeatEditorCubit()..load(projectId, initialPlayheadMs: 15000),
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
      body: BlocBuilder<BeatEditorCubit, BeatEditorState>(
        builder: (context, state) => switch (state) {
          BeatEditorLoading() => Center(
            child: CircularProgressIndicator(color: kv.volt),
          ),
          BeatEditorError(:final error) => Center(
            child: Text(error, style: KvText.ui(color: kv.error)),
          ),
          final BeatEditorReady s => _EditorLayout(state: s),
        },
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
