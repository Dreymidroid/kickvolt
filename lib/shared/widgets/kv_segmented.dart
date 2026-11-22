import 'package:material_ui/material_ui.dart';

import '../styles/kv_colors.dart';
import '../styles/kv_text.dart';

/// Pill segmented control (h44, radius 22). The selected segment is volt.
class KvSegmented<T> extends StatelessWidget {
  const KvSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.mono = false,
    this.fontSize = 14,
  });

  /// (value, label) pairs, in display order.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;
  final bool mono;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Semantics(
      label: semanticLabel,
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: kv.surface2,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kv.border),
        ),
        child: Row(
          children: [
            for (final (i, (v, label)) in options.indexed) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: v == value,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(v),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == value ? kv.volt : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        label,
                        style: _style(v == value ? kv.onVolt : kv.text2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _style(Color color) => mono
      ? KvText.mono(size: fontSize, weight: FontWeight.w600, color: color)
      : KvText.ui(size: fontSize, weight: FontWeight.w600, color: color);
}
