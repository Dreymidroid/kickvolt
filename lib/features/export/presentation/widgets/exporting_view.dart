import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../../import/presentation/pages/analyzing_screen.dart'
    show ProgressRing;
import '../../bloc/export_cubit.dart';
import '../../domain/entities/beat_pack.dart';

/// Export progress (`Exporting.png`). Back and swipe cancel.
class ExportingView extends StatelessWidget {
  const ExportingView({super.key, required this.plan, required this.progress});

  final BeatPackPlan plan;
  final ExportProgress progress;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<ExportCubit>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.cancel();
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const Spacer(flex: 2),
              ProgressRing(progress: progress.overallFraction, size: 140),
              const SizedBox(height: 26),
              Text(
                'Building your beat pack',
                textAlign: TextAlign.center,
                style: KvText.ui(size: 26, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                progress.stepText,
                textAlign: TextAlign.center,
                style: KvText.ui(size: 14, color: kv.text2),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kv.surface1,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kv.border),
                ),
                child: Column(
                  children: [
                    for (final (i, f) in progress.files.indexed) ...[
                      if (i > 0) Container(height: 1, color: kv.border),
                      _FileRow(file: f),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: KvSecondaryButton(
                  label: 'Cancel',
                  onPressed: cubit.cancel,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final ExportFileProgress file;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final pct = (file.fraction * 100).floor().clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  file.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: KvText.mono(size: 13),
                ),
              ),
              if (file.completed)
                KvIcon(KvIcons.check, size: 16, color: kv.volt)
              else
                Text('$pct%', style: KvText.mono(size: 12, color: kv.text2)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            file.kind.displayLabel,
            style: KvText.ui(size: 12, color: kv.text2),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: kv.surface3),
                  FractionallySizedBox(
                    widthFactor: file.completed
                        ? 1.0
                        : file.fraction.clamp(0.0, 1.0),
                    child: Container(color: kv.volt),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
