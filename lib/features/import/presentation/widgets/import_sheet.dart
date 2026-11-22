import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/picked_source.dart';

/// "Import a song" bottom sheet. Resolves to the chosen source kind, or
/// null if dismissed.
Future<ImportSourceKind?> showImportSheet(BuildContext context) =>
    showModalBottomSheet<ImportSourceKind>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ImportSheet(),
    );

class ImportSheet extends StatelessWidget {
  const ImportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    void choose(ImportSourceKind k) => Navigator.of(context).pop(k);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Import a song',
                    style: KvText.ui(size: 24, weight: FontWeight.w700),
                  ),
                ),
                KvIconButton(
                  icon: KvIcons.close,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SourceCard(
              icon: KvIcons.folder,
              title: 'Files',
              subtitle: 'MP3, M4A, WAV or AAC',
              onTap: () => choose(ImportSourceKind.file),
            ),
            const SizedBox(height: 14),
            _SourceCard(
              icon: KvIcons.music,
              title: 'Music library',
              subtitle: 'Songs downloaded to this phone',
              onTap: () => choose(ImportSourceKind.library),
            ),
            const SizedBox(height: 14),
            _SourceCard(
              icon: KvIcons.video,
              title: 'From a video',
              subtitle: 'Pull the audio out of a clip in your camera roll',
              onTap: () => choose(ImportSourceKind.video),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, left: 4),
                  child: KvIcon(KvIcons.help, size: 18, color: kv.text2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use the exact audio you’ll edit with (same version, '
                    'same speed) so the beats line up.',
                    style: KvText.ui(size: 14, color: kv.text2, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final KvIcons icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Material(
      color: kv.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: kv.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kv.volt.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: KvIcon(icon, size: 22, color: kv.volt),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KvText.ui(size: 16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KvText.ui(size: 13.5, color: kv.text2),
                    ),
                  ],
                ),
              ),
              KvIcon(KvIcons.chevronRight, size: 20, color: kv.text2),
            ],
          ),
        ),
      ),
    );
  }
}
