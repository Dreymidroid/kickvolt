import 'package:material_ui/material_ui.dart';

import '../../../../core/audio_native/audio_native_client.dart';
import '../../../../shared/shared.dart';

/// Android music library list (MediaStore). Resolves to the chosen track.
Future<LibraryTrack?> showLibraryTrackSheet(
  BuildContext context,
  List<LibraryTrack> tracks,
) => showModalBottomSheet<LibraryTrack>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.95,
    builder: (context, controller) =>
        LibraryTrackList(tracks: tracks, controller: controller),
  ),
);

class LibraryTrackList extends StatelessWidget {
  const LibraryTrackList({super.key, required this.tracks, this.controller});

  final List<LibraryTrack> tracks;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Music library',
            style: KvText.ui(size: 24, weight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No songs found on this phone. Try importing from Files '
                      'instead.',
                      textAlign: TextAlign.center,
                      style: KvText.ui(size: 15, color: kv.text2),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: controller,
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return ListTile(
                      minTileHeight: 60,
                      leading: KvIcon(KvIcons.music, size: 22, color: kv.text2),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KvText.ui(size: 15, weight: FontWeight.w600),
                      ),
                      subtitle: t.artist == null
                          ? null
                          : Text(
                              t.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KvText.ui(size: 13, color: kv.text2),
                            ),
                      trailing: Text(
                        formatDuration(t.durationMs),
                        style: KvText.mono(size: 12, color: kv.text3),
                      ),
                      onTap: () => Navigator.of(context).pop(t),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// `m:ss` for a duration in milliseconds.
String formatDuration(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
