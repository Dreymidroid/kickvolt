import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line icons copied from the design HTML (Lucide-style, 24×24, stroke 2).
enum KvIcons {
  chevronLeft('<path d="m15 18-6-6 6-6"/>'),
  chevronRight('<path d="m9 18 6-6-6-6"/>'),
  trash(
    '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  ),
  vibrate(
    '<rect x="8" y="5" width="8" height="14" rx="1.5"/><path d="m3 8 2 2-2 2 2 2M21 8l-2 2 2 2-2 2"/>',
  ),
  undo('<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>'),
  redo('<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>'),
  magnet(
    '<path d="m6 15-4-4 6.75-6.77a7.79 7.79 0 0 1 11 11L13 22l-4-4 6.39-6.36a2.14 2.14 0 0 0-3-3L6 15"/>'
    '<path d="m5 8 4 4M12 15l4 4"/>',
  ),
  volume(
    '<path d="M11 5 6 9H2v6h4l5 4V5z"/>'
    '<path d="M15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14"/>',
  ),
  zoom('<path d="M7 17 3 21M17 7l4-4M3 16v5h5M21 8V3h-5"/>'),
  back2(
    '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
  ),
  fwd2(
    '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
  ),
  play('<path d="M7 4v16l13-8z" fill="currentColor"/>'),
  pause(
    '<rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor"/>'
    '<rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor"/>',
  ),
  tap(
    '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3.5" fill="currentColor"/>',
  ),
  plus('<path d="M12 5v14M5 12h14"/>'),
  sparkle(
    '<path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"/>',
  ),
  move('<path d="M5 9l-3 3 3 3M19 9l3 3-3 3M2 12h20M12 5v14"/>'),
  layers(
    '<path d="m12 2 10 5-10 5L2 7z"/><path d="m2 17 10 5 10-5"/><path d="m2 12 10 5 10-5"/>',
  ),
  scissors(
    '<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/>'
    '<path d="M20 4 8.12 15.88M14.47 14.48 20 20M8.12 8.12 12 12"/>',
  ),
  bolt('<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z" fill="currentColor"/>'),
  alertCircle(
    '<circle cx="12" cy="12" r="10"/>'
    '<path d="M12 8v4M12 16h.01"/>',
  ),
  close('<path d="M18 6 6 18M6 6l12 12"/>'),
  check('<path d="M20 6 9 17l-5-5"/>'),
  help(
    '<circle cx="12" cy="12" r="10"/>'
    '<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3M12 17h.01"/>',
  ),
  sliders(
    '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
  ),
  folder(
    '<path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z"/>',
  ),
  music(
    '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/>'
    '<circle cx="18" cy="16" r="3"/>',
  ),
  video(
    '<rect x="2" y="6" width="14" height="12" rx="2"/><path d="m22 8-6 4 6 4V8Z"/>',
  ),
  download(
    '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
  ),
  share(
    '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8M16 6l-4-4-4 4M12 2v13"/>',
  ),
  file(
    '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/>'
    '<path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
  );

  const KvIcons(this.body);
  final String body;
}

class KvIcon extends StatelessWidget {
  const KvIcon(
    this.icon, {
    super.key,
    this.size = 22,
    required this.color,
    this.strokeWidth = 2,
  });

  final KvIcons icon;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="$strokeWidth" '
      'stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}
