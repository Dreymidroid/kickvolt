import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../bloc/beat_editor_cubit.dart';
import '../widgets/auto_detect_sheet.dart';
import '../widgets/beat_inspector_panel.dart';
import '../widgets/beat_timeline.dart';
import '../widgets/bulk_panel.dart';
import '../widgets/detect_failed_sheet.dart';
import '../widgets/edit_panel.dart';
import '../widgets/editor_controls.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/playing_panel.dart';
import '../widgets/sections_panel.dart';
import '../widgets/tap_panel.dart';

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
        listenWhen: (prev, curr) {
          if (curr is! BeatEditorReady) return false;
          final saveChanged =
              curr.saveError != null &&
              (prev is! BeatEditorReady || prev.saveError != curr.saveError);
          final infoChanged =
              curr.infoMessage != null &&
              (prev is! BeatEditorReady ||
                  prev.infoMessage != curr.infoMessage);
          return saveChanged || infoChanged;
        },
        listener: (context, state) {
          if (state is! BeatEditorReady) return;
          if (state.saveError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('Could not save: ${state.saveError}')),
              );
          } else if (state.infoMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.infoMessage!)));
            context.read<BeatEditorCubit>().clearInfoMessage();
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
    final cubit = context.read<BeatEditorCubit>();
    final hasSheet = state.activeSheet != EditorSheet.none;

    return Stack(
      children: [
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: EditorTopBar(
                state: state,
                onExport: () async {
                  await cubit.flushPendingSave();
                  if (!context.mounted) return;
                  unawaited(
                    context.router.push(
                      ExportRoute(projectId: state.project.id),
                    ),
                  );
                },
              ),
            ),
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
        ),
        if (hasSheet) ...[
          // Dim scrim matching `rgba(5,5,8,0.55)` in EditorAutoDetect / EditorDetectFailed.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: cubit.closeSheet,
              child: Container(color: const Color(0x8C050508)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: switch (state.activeSheet) {
              EditorSheet.autoDetect => AutoDetectSheet(state: state),
              EditorSheet.detectFailed => DetectFailedSheet(state: state),
              EditorSheet.none => const SizedBox.shrink(),
            },
          ),
        ],
      ],
    );
  }

  Widget _contextPanel() => switch (state.tool) {
    EditorTool.edit =>
      state.selectedIndex != null
          ? BeatInspectorPanel(state: state)
          : state.playing
          ? PlayingPanel(state: state)
          : EditPanel(state: state),
    EditorTool.tap => TapPanel(state: state),
    EditorTool.sections => SectionsPanel(state: state),
    EditorTool.bulk => BulkPanel(state: state),
    EditorTool.auto => const SizedBox.shrink(),
  };
}
