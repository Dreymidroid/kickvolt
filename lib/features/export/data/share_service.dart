import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet. An interface so widget tests never touch the
/// plugin.
abstract interface class ShareService {
  /// Shares all [paths] in one sheet.
  Future<void> shareFiles(List<String> paths, {Rect? sharePositionOrigin});
}

class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareFiles(
    List<String> paths, {
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final path in paths) XFile(path)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
