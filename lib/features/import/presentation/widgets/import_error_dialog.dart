import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/import_failure.dart';

enum ImportErrorAction { chooseFile, extractVideo }

/// "Can't open this file" card. Resolves to the follow-up the user chose.
Future<ImportErrorAction?> showImportErrorDialog(
  BuildContext context,
  ImportFailure failure,
) => showDialog<ImportErrorAction>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.6),
  builder: (_) => ImportErrorDialog(failure: failure),
);

class ImportErrorDialog extends StatelessWidget {
  const ImportErrorDialog({super.key, required this.failure});

  final ImportFailure failure;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final body = KvText.ui(size: 15, color: kv.text2, height: 1.45);
    final name = failure.fileName;
    final showName =
        name != null && failure.kind != ImportFailureKind.permissionDenied;
    return Dialog(
      backgroundColor: kv.surface1,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: kv.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kv.error.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: KvIcon(KvIcons.file, size: 24, color: kv.error),
            ),
            const SizedBox(height: 16),
            Text(
              failure.title,
              textAlign: TextAlign.center,
              style: KvText.ui(size: 21, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  if (showName)
                    TextSpan(
                      text: '$name ',
                      style: body.copyWith(color: kv.text1),
                    ),
                  TextSpan(text: failure.message),
                ],
              ),
              textAlign: TextAlign.center,
              style: body,
            ),
            const SizedBox(height: 22),
            KvPrimaryButton(
              label: 'Choose another file',
              height: 52,
              onPressed: () =>
                  Navigator.of(context).pop(ImportErrorAction.chooseFile),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: KvSecondaryButton(
                label: 'Extract from a video',
                icon: KvIcons.video,
                onPressed: () =>
                    Navigator.of(context).pop(ImportErrorAction.extractVideo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
