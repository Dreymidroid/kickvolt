import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../bloc/export_cubit.dart';
import '../../domain/entities/export_failure.dart';
import '../../domain/entities/export_options.dart';

/// Error card over the Export screen (`ExportFailed.png`).
class ExportFailedSheet extends StatelessWidget {
  const ExportFailedSheet({
    super.key,
    required this.failure,
    required this.options,
  });

  final ExportFailure failure;
  final ExportOptions options;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<ExportCubit>();
    final kind = failure.kind;
    final canRetry = kind != ExportFailureKind.sourceMissing;
    final switchLabel = switch (kind) {
      ExportFailureKind.diskFull when options.format == AudioFormat.wav =>
        'Switch to M4A and retry',
      ExportFailureKind.encodeFailed => 'Switch to WAV and retry',
      _ => null,
    };

    return Stack(
      children: [
        Positioned.fill(child: Container(color: const Color(0xB8050508))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: kv.surface1,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(top: BorderSide(color: kv.border)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kv.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: KvIcon(
                          KvIcons.alertCircle,
                          size: 22,
                          color: kv.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          failure.title,
                          style: KvText.heading(size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    failure.message,
                    style: KvText.ui(size: 15, color: kv.text2, height: 1.45),
                  ),
                  if (kind == ExportFailureKind.other &&
                      failure.detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      failure.detail!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: KvText.mono(size: 11, color: kv.text3),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (canRetry)
                    KvPrimaryButton(label: 'Try again', onPressed: cubit.retry),
                  if (switchLabel != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: KvSecondaryButton(
                        label: switchLabel,
                        onPressed: cubit.switchFormatAndRetry,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: cubit.dismissFailure,
                      child: Text(
                        'Cancel',
                        style: KvText.ui(
                          size: 15,
                          weight: FontWeight.w600,
                          color: kv.text2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
