import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../../import/presentation/widgets/library_track_sheet.dart'
    show formatDuration;
import '../../bloc/export_cubit.dart';
import '../../domain/entities/beat_pack.dart';
import '../../domain/entities/export_options.dart';

/// Success screen (`ExportSuccess.png`). "Open in CapCut/VN" is replaced by
/// Share and Save to Files: neither app documents a way to receive a file.
class ExportSuccessView extends StatelessWidget {
  const ExportSuccessView({super.key, required this.state});

  final ExportDone state;

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';

  String _detail(ExportedFile f) {
    final duration = formatDuration(state.pack.durationMs);
    final label = f.kind.displayLabel;
    final base = f.clickCount == null
        ? '$label · $duration'
        : '$label · ${f.clickCount} ${f.clickCount == 1 ? 'click' : 'clicks'}';
    return '$base · ${_size(f.byteSize)}';
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final cubit = context.read<ExportCubit>();
    final pack = state.pack;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.router.popUntilRoot(),
              child: Text(
                'Done',
                style: KvText.ui(
                  size: 16,
                  weight: FontWeight.w600,
                  color: kv.volt,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kv.volt,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kv.volt.withValues(alpha: 0.12),
                    spreadRadius: 12,
                  ),
                  BoxShadow(
                    color: kv.volt.withValues(alpha: 0.55),
                    blurRadius: 60,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: KvIcon(
                KvIcons.check,
                size: 46,
                color: kv.onVolt,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Beat pack ready',
            textAlign: TextAlign.center,
            style: KvText.heading(size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            state.saved ? 'Saved to the folder you picked' : 'Ready to share',
            textAlign: TextAlign.center,
            style: KvText.ui(size: 14, color: kv.text2),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: kv.surface1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kv.border),
            ),
            child: Column(
              children: [
                for (final (i, f) in pack.files.indexed) ...[
                  if (i > 0) Container(height: 1, color: kv.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: kv.surface2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: KvIcon(
                            f.kind == ExportFileKind.guide
                                ? KvIcons.bolt
                                : f.kind == ExportFileKind.preview
                                ? KvIcons.volume
                                : KvIcons.music,
                            size: 18,
                            color: kv.volt,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: KvText.mono(size: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _detail(f),
                                style: KvText.ui(size: 12, color: kv.text2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Builder(
            builder: (buttonContext) => KvPrimaryButton(
              label: 'Share',
              icon: KvIcons.share,
              onPressed: () {
                final box = buttonContext.findRenderObject() as RenderBox?;
                final origin = box != null && box.hasSize
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null;
                cubit.share(sharePositionOrigin: origin);
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: KvSecondaryButton(
              label: 'Save to Files',
              icon: KvIcons.folder,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final saved = await cubit.saveToFiles();
                if (saved > 0) {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          'Saved $saved ${saved == 1 ? 'file' : 'files'}',
                        ),
                      ),
                    );
                }
              },
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => context.router.push(HowToRoute()),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KvIcon(KvIcons.help, size: 18, color: kv.volt),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'How to use it in CapCut and VN',
                    overflow: TextOverflow.ellipsis,
                    style: KvText.ui(
                      size: 15,
                      weight: FontWeight.w600,
                      color: kv.volt,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
