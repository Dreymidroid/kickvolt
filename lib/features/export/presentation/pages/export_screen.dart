import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/export_cubit.dart';
import '../widgets/export_failed_sheet.dart';
import '../widgets/export_options_view.dart';
import '../widgets/export_success_view.dart';
import '../widgets/exporting_view.dart';

/// Export flow: options → exporting → (failed | success), driven by
/// [ExportCubit]. All four design screens live behind this one route.
@RoutePage()
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key, required this.projectId, this.cubit});

  final String projectId;

  /// For tests.
  final ExportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? (ExportCubit()..load(projectId)),
      child: const ExportView(),
    );
  }
}

class ExportView extends StatelessWidget {
  const ExportView({super.key});

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Scaffold(
      backgroundColor: kv.background,
      body: BlocBuilder<ExportCubit, ExportState>(
        builder: (context, state) => switch (state) {
          ExportLoading() => Center(
            child: CircularProgressIndicator(color: kv.volt),
          ),
          ExportError(:final message) => _ErrorView(message: message),
          final ExportEditing s => ExportOptionsView(
            project: s.project,
            options: s.options,
            plan: s.plan,
            quota: s.quota,
            videoAllowed: s.videoAllowed,
            onVideoLocked: context.read<ExportCubit>().onVideoLocked,
          ),
          final ExportFailed s => Stack(
            children: [
              ExportOptionsView(
                project: s.project,
                options: s.options,
                plan: s.plan,
                quota: s.quota,
                videoAllowed: s.videoAllowed,
                onVideoLocked: context.read<ExportCubit>().onVideoLocked,
              ),
              ExportFailedSheet(failure: s.failure, options: s.options),
            ],
          ),
          final ExportExporting s => ExportingView(
            plan: s.plan,
            progress: s.progress,
          ),
          final ExportDone s => ExportSuccessView(state: s),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

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
                'Could not open export',
                textAlign: TextAlign.center,
                style: KvText.heading(size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: KvText.ui(size: 15, color: kv.error),
              ),
              const SizedBox(height: 24),
              KvSecondaryButton(
                label: 'Back',
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
