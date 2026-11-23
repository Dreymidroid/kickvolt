import 'dart:io';

import '../../../../core/audio_math/click_synth.dart';
import '../../../../core/storage/project_paths.dart';
import '../../../beat_detection/domain/beat_filter_view.dart';
import '../../../projects/domain/entities/project.dart';
import '../preview_isolate_runner.dart';

/// Renders pre-mixed `song + clicks` WAV files for sample-accurate click
/// preview in the beat editor (§5.3).
abstract interface class ClickPreviewRepository {
  /// Renders a preview mix for [project]'s **visible** beats in [style],
  /// returning the path of the completed WAV file.
  Future<String> render(
    Project project, {
    required ClickStyle style,
    required ClickPreviewCancelToken cancel,
  });

  /// Deletes a single previously-rendered preview file (called only after the
  /// player has switched away from it).
  Future<void> deleteFile(String path);

  /// Deletes all stray `preview-*` files in [projectId]'s folder (called on
  /// editor load and in `close()`).
  Future<void> cleanUpProject(String projectId);
}

class ClickPreviewRepositoryImpl implements ClickPreviewRepository {
  ClickPreviewRepositoryImpl({required this._paths});

  final Future<ProjectPaths> Function() _paths;
  int _sequence = 0;

  @override
  Future<String> render(
    Project project, {
    required ClickStyle style,
    required ClickPreviewCancelToken cancel,
  }) async {
    final paths = await _paths();
    final seq = ++_sequence;
    final songPath = paths.songWav(project.id);
    final outPath = paths.previewWav(project.id, seq);

    final visibleSamples = <int>[
      for (final idx in visibleBeatIndices(project)) project.beats[idx].sample,
    ];

    await runPreviewMixInIsolate(
      songWavPath: songPath,
      outputWavPath: outPath,
      beatSamples: visibleSamples,
      style: style,
      cancelToken: cancel,
    );

    if (cancel.isCancelled) {
      await deleteFile(outPath);
      throw const ClickPreviewCancelledException();
    }
    return outPath;
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<void> cleanUpProject(String projectId) async {
    try {
      final paths = await _paths();
      await paths.deletePreviewFiles(projectId);
    } catch (_) {}
  }
}
