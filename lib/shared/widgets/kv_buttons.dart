import 'package:material_ui/material_ui.dart';

import '../styles/kv_colors.dart';
import '../styles/kv_text.dart';
import 'kv_icon.dart';

/// Transparent round icon button, 44 px minimum touch target.
class KvIconButton extends StatelessWidget {
  const KvIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 44,
    this.iconSize = 22,
    this.color,
  });

  final KvIcons icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final fg = onPressed == null ? kv.text3 : (color ?? kv.text1);
    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: KvIcon(icon, size: iconSize, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill toggle chip (h40, radius 20). Active = volt tint.
class KvChip extends StatelessWidget {
  const KvChip({
    super.key,
    required this.label,
    this.icon,
    this.active = false,
    this.mono = false,
    required this.onPressed,
  });

  final String label;
  final KvIcons? icon;
  final bool active;
  final bool mono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    final fg = active ? kv.volt : kv.text2;
    final style = mono
        ? KvText.mono(size: 13, weight: FontWeight.w600, color: fg)
        : KvText.ui(size: 13, weight: FontWeight.w600, color: fg);
    return Semantics(
      button: true,
      toggled: active,
      child: Material(
        color: active ? kv.volt.withValues(alpha: 0.14) : kv.surface2,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? kv.volt.withValues(alpha: 0.5) : kv.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  KvIcon(icon!, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button: h48, radius 16, surface2 with border.
class KvSecondaryButton extends StatelessWidget {
  const KvSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  final String label;
  final KvIcons? icon;
  final VoidCallback? onPressed;

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
        onTap: onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                KvIcon(icon!, size: 20, color: kv.text1),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: KvText.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: kv.text1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
