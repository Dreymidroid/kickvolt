import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/project_summary.dart';

enum ProjectCardAction { rename, delete }

Future<ProjectCardAction?> showProjectActionsSheet(
  BuildContext context,
  ProjectSummary summary,
) {
  final kv = context.kv;
  return showModalBottomSheet<ProjectCardAction>(
    context: context,
    backgroundColor: kv.surface1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kv.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                summary.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KvText.heading(size: 18, color: kv.text1),
              ),
            ),
            const SizedBox(height: 12),
            _SheetTile(
              icon: KvIcons.file,
              label: 'Rename',
              color: kv.text1,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ProjectCardAction.rename),
            ),
            const SizedBox(height: 8),
            _SheetTile(
              icon: KvIcons.trash,
              label: 'Delete',
              color: kv.error,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ProjectCardAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final KvIcons icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Material(
      color: kv.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kv.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                KvIcon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: KvText.ui(
                    size: 16,
                    weight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> showRenameProjectDialog(
  BuildContext context, {
  required String currentTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(currentTitle: currentTitle),
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentTitle});

  final String currentTitle;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final canSave = _controller.text.trim().isNotEmpty;
    return Dialog(
      backgroundColor: kv.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: kv.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rename project', style: KvText.heading(size: 20)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              style: KvText.ui(size: 16, color: kv.text1),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                filled: true,
                fillColor: kv.surface2,
                hintText: 'Song title',
                hintStyle: KvText.ui(size: 16, color: kv.text3),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: kv.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: kv.volt),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: KvSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KvPrimaryButton(
                    label: 'Save',
                    height: 48,
                    fontSize: 15,
                    onPressed: canSave ? _submit : null,
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

Future<bool> showDeleteProjectDialog(
  BuildContext context, {
  required String title,
}) async {
  final kv = context.kv;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: kv.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: kv.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Delete "$title"?', style: KvText.heading(size: 20)),
            const SizedBox(height: 10),
            Text(
              'This removes the project and its decoded audio from your device.',
              style: KvText.ui(size: 15, color: kv.text2, height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: KvSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: kv.error,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            'Delete',
                            style: KvText.ui(
                              size: 15,
                              weight: FontWeight.w700,
                              color: kv.onVolt,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
